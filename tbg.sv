`ifndef TBG
`define TBG
typedef struct packed {
    int unsigned addr;
    int unsigned data;
} bitstream_entry_t;

typedef enum int {
    IDLE = 0,
    QUEUED = 1,
    CONFIG = 2,
    RUNNING = 3,
    FINISH = 4
} app_state_t;

typedef byte unsigned data_array_t[$];
typedef bitstream_entry_t bitstream_t[$];

class IOHelper;
    static function data_array_t get_input_data(string filename);
        byte unsigned result[$];
        int fp = $fopen(filename, "rb");
        assert_(fp != 0, "Unable to read input file");
        while (!$feof(fp)) begin
            byte unsigned value;
            int code;
            code = $fread(value, fp);
            if (code != 1) break;
            result.push_back(value);
        end
        $fclose(fp);
        return result;
    endfunction

    static function bitstream_t get_bitstream(string bitstream_filename);
        bitstream_t result;
        int fp = $fopen(bitstream_filename, "r");
        assert_(fp != 0, "Unable to read bitstream file");
        while (!$feof(fp)) begin
            int unsigned addr;
            int unsigned data;
            int code;
            bitstream_entry_t entry;
            code = $fscanf(fp, "%08x %08x", entry.addr, entry.data);
            if (code == -1) continue;
            assert_(code == 2 , $sformatf("Incorrect bs format. Expected 2 entries, got: %d. Current entires: %d", code, result.size()));
            result.push_back(entry);
        end
        return result;
    endfunction

    static function data_array_t get_gold_data(string filename);
        byte unsigned result[$];
        byte unsigned value;
        int fp, code;
        fp = $fopen(filename, "rb");
        assert_(fp != 0, "Unable to read gold file");
        while (!$feof(fp)) begin
            code = $fread(value, fp);
            if (code)
                result.push_back(value);
        end
        return result;
    endfunction

    static function void assert_(bit cond, string msg);
        assert (cond) else begin
            $display("%s", msg);
            $stacktrace;
            $finish(1);
        end
    endfunction

endclass

`endif

module tbg_driver #(
    parameter int MAX_NUM_APP = 2,
    parameter int GROUP_SIZE = 4,
    parameter int X_OFFSET = 4,

    parameter int MAX_NUM_APP_WIDTH = $clog2(MAX_NUM_APP + 1)
) (
    output logic                 clk,
    input  logic[31:0]           read_config_data,
    output logic                 reset,
    output logic                 stall,
    output logic[31:0]           config_addr,
    output logic[31:0]           config_data,
    output logic                 config_read,
    output logic                 config_write,
    output logic[MAX_NUM_APP_WIDTH-1:0][15:0]  inputs,
    output logic[MAX_NUM_APP_WIDTH-1:0]        resets,
    input  logic[MAX_NUM_APP_WIDTH-1:0][15:0]  outputs,
    input  logic[MAX_NUM_APP_WIDTH-1:0]        valids
);

localparam CLOCK_PERIOD = 10;
initial clk = 0;
always #(CLOCK_PERIOD/2.0) clk = ~clk;

data_array_t input_data[MAX_NUM_APP];
data_array_t output_data[MAX_NUM_APP];
app_state_t  app_states[MAX_NUM_APP];
int          output_sizes[MAX_NUM_APP];
data_array_t gold_data[MAX_NUM_APP];
bitstream_t  bitstreams[];
int          queue_time[MAX_NUM_APP];

int num_app;

semaphore config_lock;
// only one app can config at a time
initial config_lock = new(1);

// we use clk as default clocking
default clocking @(posedge clk);
endclocking

bit initialized = 0;

task run_app(int i);
    automatic int j = i;
    forever
    case (app_states[j])
        QUEUED: begin
            queue_time[j] -= 1;
            if (queue_time[j] <= 0) begin
                $display("start to config for app %0d @%0d", j, $time);
                app_states[j] = CONFIG;
            end
            ##1;
        end
        CONFIG: begin
            #(CLOCK_PERIOD-1);
            foreach (bitstreams[j][k]) begin
                // obtain the lock
                config_lock.get(1);
                config_write = 1;
                config_read  = 0;
                config_addr  = bitstreams[j][k].addr;
                config_data  = bitstreams[j][k].data;
                #(CLOCK_PERIOD);
                // read back
                config_write = 0;
                config_read  = 1;
                #(CLOCK_PERIOD);
                IOHelper::assert_(read_config_data == bitstreams[j][k].data, $sformatf("[%0d] expected to read out %08X. got %08X", k, bitstreams[j][k].data, read_config_data));
                config_lock.put(1);
            end
            // finished configuration
            config_lock.get(1);
            config_write = 0;
            config_read = 0;
            config_lock.put(1);
            #1;
            // need to assert reset and then start
            resets[j] = 1;
            #(CLOCK_PERIOD);
            resets[j] = 0;
            // start the application
            app_states[j] = RUNNING;
            $display("start to run app %0d @%0d", j, $time);
        end
        RUNNING: begin
            if (input_data[j].size()) begin
                inputs[j] = input_data[j].pop_front() & 'hFF;
            end
            if (valids[j]) begin
                output_data[j].push_back(outputs[j][7:0]);
            end
            if (output_data[j].size() == output_sizes[j]) begin
                ##20;
                $display("App %0d finished @%0d", j, $time);
                app_states[j] = FINISH;
            end
            #(CLOCK_PERIOD);
        end
        default: begin
            // nothing
            ##1;
        end
    endcase
endtask

// fork process to set input at every cycle
initial begin
    // block this process until initialized
    wait (initialized);
    for (int i = 0; i < num_app; i++) begin
        fork
            automatic int j = i;
            begin
                run_app(j);
            end
        join_none
    end
end

// read out bitstream and then config it
// also read out the inputs
initial begin
    int fp;
    string app_dirs[$], temp_str;

    num_app = MAX_NUM_APP;
    for (int i = 0; i < MAX_NUM_APP; i++) begin
        automatic string arg_name = {$sformatf("APP%0d", i), "=%s"};
        if ($value$plusargs(arg_name, temp_str)) begin
            // we have it
            app_dirs.push_back(temp_str);
        end
        else begin
            num_app = i;
            break;
        end
    end
    bitstreams = new[num_app];

    foreach (app_dirs[i]) begin
        // get app name
        automatic string app_name;
        automatic string dir;
        automatic string bs_location, input_location, gold_location;
        automatic int last_str;
        dir = app_dirs[i];
        last_str = dir.getc(dir.len() - 1) == "/"? dir.len() - 2: dir.len() - 1;

        for (int i = dir.len() - 1; i >= 0; i--) begin
            if (dir.getc(i) == "/" && i != (dir.len() - 1)) begin
                app_name = dir.substr(i + 1, last_str);
                break;
            end
        end
        if (app_name.len() == 0) app_name = dir;
        bs_location = {dir, "/bin/", app_name, ".bs"};
        input_location = {dir, "/bin/", "input.raw"};
        gold_location = {dir, "/bin/", "gold.raw"};

        bitstreams[i] = IOHelper::get_bitstream(bs_location);
        input_data[i] = IOHelper::get_input_data(input_location);
        gold_data[i]  = IOHelper::get_gold_data(gold_location);
        output_sizes[i] = gold_data[i].size();
        app_states[i] = IDLE;
    end

    // compute the offset and then change them
    foreach (bitstreams[i]) begin
        automatic int offset = i * X_OFFSET;
        if (i >= num_app) break;
        foreach (bitstreams[i][j]) begin
            int addr, x;
            addr = bitstreams[i][j].addr;
            x = (addr >> 8) & 'hFF;
            x = x + offset;
            addr = (addr & 'hFFFF00FF) | (x << 8);
            bitstreams[i][j].addr = addr;
        end
    end

    // zero out some signal values
    stall = 0;
    foreach (resets[i]) begin
        resets[i] = 0;
    end

    // hit reset for a cycle
    // reset hi
    reset = 1;
    ##2
    reset = 0;
    ##1;

    // ready to start
    foreach (app_states[i]) begin
        if (i >= num_app) break;
        $display("queued app %0d to config", i);
        app_states[i] = QUEUED;
        // set random sleep time
        queue_time[i] = $urandom(i) % 1000;
    end
    
    initialized = 'b1;
end

task check_gold_output(int app_id);
    automatic int i = app_id;
    for (int j = 0; j < gold_data[i].size(); j++) begin
        IOHelper::assert_(gold_data[i][j] == output_data[i][j], $sformatf("[%0d] Get %02X but expect %02X", j, output_data[i][j], gold_data[i][j]));
    end
    $display("APP %0d passed with %0d outputs", i, gold_data[i].size());
endtask

initial begin
    // we repeat on 200000 clocks
    bit finish;
    bit finished[MAX_NUM_APP];
    for (int i = 0; i < num_app; i++) finished[i] = 'b0;

    repeat (15000) @(posedge clk) begin
        // if all apps finishes, we are good
        finish = 'b1;
        foreach (app_states[i]) begin
            if (i >= num_app) break;
            if (app_states[i] != FINISH) begin
                finish = 0;
                break;
            end
            else if (!finished[i]) begin
                finished[i] = 'b1;
                check_gold_output(i);
            end
        end
        if (finish) begin
            $finish();
        end
    end
    $error(1);
end
endmodule


module top;

localparam MAX_NUM_APP = 2;
localparam MAX_NUM_APP_WIDTH = $clog2(MAX_NUM_APP + 1);

logic                 clk;
logic[31:0]           read_config_data;
logic                 reset;
logic                 stall;
logic[31:0]           config_addr;
logic[31:0]           config_data;
logic                 config_read;
logic                 config_write;
logic[MAX_NUM_APP_WIDTH-1:0][15:0]  inputs;
logic[MAX_NUM_APP_WIDTH-1:0]        resets;
logic[MAX_NUM_APP_WIDTH-1:0][15:0]  outputs;
logic[MAX_NUM_APP_WIDTH-1:0]        valids;

// compute the x offset
`ifdef APP1_4
localparam int X_OFFSET = 4;
`elsif APP1_8
localparam int X_OFFSET = 8;
`elsif APP1_8
localparam int X_OFFSET = 16;
`else
localparam int X_OFFSET = 4;
`endif

tbg_driver #(.MAX_NUM_APP(MAX_NUM_APP),
             .X_OFFSET(X_OFFSET))
           driver (.*);

logic[7:0] stall_signal;
assign stall_signal = {8{stall}};

Interconnect dut(
    .config_config_addr(config_addr),
    .config_config_data(config_data),
    .read_config_data(read_config_data),
    .glb2io_16_X00_Y00(inputs[0]),
    .io2glb_16_X01_Y00(outputs[0]),
    .glb2io_1_X00_Y00(resets[0]),
    .io2glb_1_X01_Y00(valids[0]),

`ifdef APP1_4
    .glb2io_16_X04_Y00(inputs[1]),
    .io2glb_16_X05_Y00(outputs[1]),
    .glb2io_1_X04_Y00(resets[1]),
    .io2glb_1_X05_Y00(valids[1]),
`endif

`ifdef APP1_8
    .glb2io_16_X08_Y00(inputs[1]),
    .io2glb_16_X09_Y00(outputs[1]),
    .glb2io_1_X08_Y00(resets[1]),
    .io2glb_1_X09_Y00(valids[1]),
`endif

`ifdef APP1_16
    .glb2io_16_X10_Y00(inputs[1]),
    .io2glb_16_X11_Y00(outputs[1]),
    .glb2io_1_X10_Y00(resets[1]),
    .io2glb_1_X11_Y00(valids[1]),
`endif

    .stall(stall_signal),
    .*
);

initial begin
    if ($test$plusargs("DEBUG")) begin
        $dumpfile("waveforms.vcd");
        $dumpvars(0,top);
    end
end

endmodule
logic start;
logic valid_out;
logic [15:0] in, data_out;

// hardcode the logic
assign start = glb2io_1_X00_Y00;
assign io2glb_1_X00_Y00 = valid_out;
assign io2glb_16_X00_Y00 = data_out;

typedef enum logic {
    IDLE = 0,
    START = 1
} app_state_t;

app_state_t state;


int outputs[];
int valid[];

int count;

initial begin
    int out_fp, valid_fp;
    int out_data[$];
    int valid_data[$];
    // need to modify the file names
    out_fp = $fopen("output.bs.out", "rb");
    valid_fp = $fopen("output.bs.out.valid", "rb");
    assert (out_fp != 0) else $finish(1);
    assert (valid_fp != 0) else $finish(1);

    while (!$feof(out_fp)) begin
        int code, value;
        code = $fread(value, out_fp);
        if (code == 1) begin
            out_data.push_back(value);
        end
    end

    while (!$feof(valid_fp)) begin
        int code, value;
        code = $fread(value, valid_fp);
        if (code == 1) begin
            valid_data.push_back(value);
        end
    end

    // valid and output should have the same size
    assert (valid_data.size() == out_data.size()) else $finish(1);
    outputs = new[valid_data.size()];
    valid = new[valid_data.size()];

    for (int i = 0; i < valid_data.size(); i++) begin
        outputs[i] = out_data[i];
        valid[i] = valid_data[i];
    end
end

always_ff @(posedge clk, posedge reset) begin
    if (reset) begin
        state <= IDLE;
    end
    else if (start) begin
        state <= START;
    end
end

always_ff @(posedge clk, posedge reset) begin
    if (reset) begin
        count <= 0;
    end
    else if (state == START) begin
        count <= count + 1;
    end
end

always_comb begin
    data_out = 0;
    valid_out = 0;
    if (state == START && count < outputs.size()) begin
        data_out = outputs[count];
        valid_out = valid[count]; 
    end
end
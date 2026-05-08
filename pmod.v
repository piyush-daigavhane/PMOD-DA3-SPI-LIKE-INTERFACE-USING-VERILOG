`timescale 1ns / 1ps

module pmod (
    input        clk,
    input        rst_n,

    input [15:0] data,
    input        data_valid,

    output reg   CS,
    output reg   LDAC_N,
    output reg   SCLK,
    output reg   DIN
);

  //----------------------------------
  // PARAMETERS
  //----------------------------------
  localparam GAP_CYCLES = 4;

  // SCLK divider
  localparam SCLK_DIV = 4;   // SCLK = clk / (2*SCLK_DIV)

  // Frame timing calculation
  localparam SHIFT_CYCLES = 16 * 2 * SCLK_DIV;
  localparam OVERHEAD     = (1 + 1 + 1 + GAP_CYCLES); // LOAD + START + DONE + GAP
  localparam MARGIN       = 15;

  localparam SAMPLE_CYCLES = SHIFT_CYCLES + OVERHEAD + MARGIN;

  //----------------------------------
  // FIXED-RATE INPUT SAMPLER
  //----------------------------------
  reg [$clog2(SAMPLE_CYCLES):0] sample_cnt;
  reg [15:0] latest_data;
  reg        latest_valid;

  reg [15:0] sampled_data;
  reg        sampled_valid;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sample_cnt    <= 0;
      latest_data   <= 0;
      latest_valid  <= 0;
      sampled_data  <= 0;
      sampled_valid <= 0;
    end else begin

      // Always capture most recent input
      if (data_valid) begin
        latest_data  <= data;
        latest_valid <= 1;
      end

      sampled_valid <= 0;

      // Fixed-rate trigger
      if (sample_cnt == SAMPLE_CYCLES-1) begin
        sample_cnt <= 0;

        if (latest_valid) begin
          sampled_data  <= latest_data;
          sampled_valid <= 1;
          latest_valid  <= 0;
        end

      end else begin
        sample_cnt <= sample_cnt + 1;
      end

    end
  end

  //----------------------------------
  // STATES
  //----------------------------------
  localparam IDLE  = 3'd0,
             LOAD  = 3'd1,
             START = 3'd2,
             SHIFT = 3'd3,
             DONE  = 3'd4,
             GAP   = 3'd5;

  reg [2:0] state, next_state;

  //----------------------------------
  // DATA PATH
  //----------------------------------
  reg [15:0] shift_reg;
  reg [4:0]  bit_cnt;

  //----------------------------------
  // GAP COUNTER
  //----------------------------------
  reg [2:0] gap_cnt;

  //----------------------------------
  // SCLK GENERATION
  //----------------------------------
  reg [$clog2(SCLK_DIV):0] clk_div_cnt;
  reg       sclk_en;
  reg       sclk_int, sclk_prev;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      clk_div_cnt <= 0;
      sclk_int    <= 0;
      sclk_prev   <= 0;
    end else begin
      sclk_prev <= sclk_int;

      if (sclk_en) begin
        if (clk_div_cnt == SCLK_DIV-1) begin
          clk_div_cnt <= 0;
          sclk_int    <= ~sclk_int;
        end else begin
          clk_div_cnt <= clk_div_cnt + 1;
        end
      end else begin
        clk_div_cnt <= 0;
        sclk_int    <= 0; // SPI mode 0 idle
      end
    end
  end

  wire sclk_falling = (sclk_prev && !sclk_int);

  //----------------------------------
  // STATE REGISTER
  //----------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  end

  //----------------------------------
  // NEXT STATE LOGIC
  //----------------------------------
  always @(*) begin
    case (state)
      IDLE:  next_state = (sampled_valid) ? LOAD : IDLE;
      LOAD:  next_state = START;
      START: next_state = SHIFT;
      SHIFT: next_state = (bit_cnt == 15 && sclk_falling) ? DONE : SHIFT;
      DONE:  next_state = GAP;
      GAP:   next_state = (gap_cnt == GAP_CYCLES) ? IDLE : GAP;
      default: next_state = IDLE;
    endcase
  end

  //----------------------------------
  // OUTPUT + DATA PATH
  //----------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      CS        <= 1;
      LDAC_N    <= 0;   // permanently LOW
      SCLK      <= 0;
      DIN       <= 0;
      shift_reg <= 0;
      bit_cnt   <= 0;
      gap_cnt   <= 0;
      sclk_en   <= 0;
    end else begin
      SCLK   <= sclk_int;
      LDAC_N <= 0;      // permanently LOW

      case (state)

        //----------------------------------
        IDLE: begin
          CS      <= 1;
          DIN     <= 0;
          bit_cnt <= 0;
          gap_cnt <= 0;
          sclk_en <= 0;
        end

        //----------------------------------
        LOAD: begin
          shift_reg <= sampled_data;
          DIN       <= sampled_data[15];
          CS        <= 0;
        end

        //----------------------------------
        START: begin
          sclk_en <= 1;
        end

        //----------------------------------
        SHIFT: begin
          if (sclk_falling) begin
            shift_reg <= {shift_reg[14:0], 1'b0};
            DIN       <= shift_reg[14];
            bit_cnt   <= bit_cnt + 1;
          end
        end

        //----------------------------------
        DONE: begin
          sclk_en <= 0;
          CS      <= 1;
        end

        //----------------------------------
        GAP: begin
          gap_cnt <= gap_cnt + 1;
        end

      endcase
    end
  end

endmodule

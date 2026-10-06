module game_core(
input   wire clk,
input   wire rst_n,
input   wire [4:0] cell_x,
input   wire [3:0] cell_y,
input   wire video_active,
input   wire game_tick,
input   wire [1:0] user_dir,
output  reg [1:0] R,G,B
);



    localparam SNAKE_LENGHT = 16;
    localparam ABS_UP    = 2'b00;
    localparam ABS_DOWN  = 2'b01;
    localparam ABS_LEFT  = 2'b10;
    localparam ABS_RIGHT = 2'b11;
    // FSM State Encodings
    
    localparam STATE_IDLE        = 2'b00;
    localparam STATE_MOVE_HEAD   = 2'b01;
    localparam STATE_MOVE_TAIL   = 2'b10;

    reg [8:0] snake_body [0:SNAKE_LENGHT-1];
    reg [$clog2(SNAKE_LENGHT)-1:0] tail_ptr;
    reg [$clog2(SNAKE_LENGHT)-1:0] read_ptr;
    

    reg gen_food;

    wire [4:0] head_x;
    wire [3:0] head_y;
    reg [1:0] head_dir;

     // State Machine and Render Registers
    reg [1:0]  state;
    reg [3:0]  food_x;
    reg [3:0]  food_y;

    reg game_over;
    reg update_body,grow_snake;

    wire [4:0] next_head_x = (head_dir == ABS_LEFT)  ? head_x - 4'd1 : (head_dir == ABS_RIGHT) ? head_x + 4'd1 : head_x;
    wire [3:0] next_head_y = (head_dir == ABS_UP)    ? head_y - 4'd1 : (head_dir == ABS_DOWN)  ? head_y + 4'd1 : head_y;
    wire eating_food = (next_head_x == food_x) && (next_head_y == food_y);

    reg is_body;
    wire is_food = (cell_x == food_x) && (cell_y == food_y); 

    wire feedback;
    reg [7:0] rnd_counter;
    assign feedback = rnd_counter[7] ^ rnd_counter[5] ^ rnd_counter[4] ^ rnd_counter[3];

    assign head_x = snake_body[0][4:0];
    assign head_y = snake_body[0][8:5];

/*Snake body as a FIFO memory using regs, the snake updates the new coordinates by shifting the content 
and pushing a new head coordinates*/
integer i;
  always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      for (i=2; i<SNAKE_LENGHT; i=i+1) begin
        snake_body[i] <= 0;
      end
      snake_body[0] <= 9'h104;
      snake_body[1] <= 9'h103;
    end else begin
      if (update_body) begin
        for (i=SNAKE_LENGHT-1; i>0; i=i-1) begin
          snake_body[i] <= snake_body[i-1];
        end
        snake_body[0] <= {next_head_y,next_head_x};
      end
    end
  end


/*snake lenght updating during the game*/
  always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      tail_ptr <= 2;
    end else begin
      if (grow_snake) begin
        tail_ptr <= tail_ptr + 1;
      end
    end
  end

    /*FSM controling the game logic, missing to avoid generating food in the same coordinates
    as the snake body*/
  always @(posedge clk, negedge rst_n) begin
        if (~rst_n) begin
            state        <= STATE_IDLE;
            head_dir     <= ABS_RIGHT;
            gen_food    <= 0;
            read_ptr <= 0;
            game_over <= 1'b0;
            grow_snake <= 0;
            update_body <= 0;
        end else begin
            case (state)
                STATE_IDLE: begin
                  if ((game_tick && !game_over)) begin
                      // Enforce 180-degree blind-turn restriction safety locks
                      if ((user_dir == ABS_UP    && head_dir != ABS_DOWN)  ||
                          (user_dir == ABS_DOWN  && head_dir != ABS_UP)    ||
                          (user_dir == ABS_LEFT  && head_dir != ABS_RIGHT) ||
                          (user_dir == ABS_RIGHT && head_dir != ABS_LEFT)) begin
                          // Drop the computed relative crumb BEFORE changing the head's absolute direction
                          head_dir <= user_dir;
                      end
                      state <= STATE_MOVE_HEAD;
                      read_ptr <= 0;
                      game_over <= 1'b0;
                      gen_food <= 0;
                      grow_snake <= 0;
                      update_body <= 0;
                  end
                    read_ptr <= 0;
                    gen_food <= 0;
                    grow_snake <= 0;
                    update_body <= 0;
                end

                STATE_MOVE_HEAD: begin
                    // 1. Boundary Wall Collision Check
                    if ((head_dir == ABS_UP    && next_head_y == 4'd15)  ||
                        (head_dir == ABS_DOWN  && next_head_y == 4'd15) ||
                        (head_dir == ABS_LEFT  && next_head_x == 5'd31)  ||
                        (head_dir == ABS_RIGHT && next_head_x == 5'd20)) begin
                        game_over <= 1'b1;
                        gen_food <= 0;
                        grow_snake <= 0;
                        update_body <= 0;
                        state <= STATE_IDLE;
                    end 
                    // 2. Self-Collision Check via single-cycle lookups
                    else if (snake_body[read_ptr]=={next_head_y,next_head_x}) begin
                        game_over <= 1'b1;
                        gen_food <= 0;
                        grow_snake <= 0;
                        update_body <= 0;
                        state <= STATE_IDLE;
                    end 
                    else if (read_ptr < tail_ptr) begin
                        read_ptr <= read_ptr + 5'd1;
                        game_over <= 1'b0;
                        gen_food <= 1'b0;
                        grow_snake <= 1'b0;
                        update_body <= 1'b0;
                        state     <= STATE_MOVE_HEAD;
                    end else begin
                        game_over <= 1'b0;
                        gen_food <= 1'b0;
                        grow_snake <= 1'b0;
                        update_body <= 1'b1;
                        state  <= STATE_MOVE_TAIL;
                    end
                end

                STATE_MOVE_TAIL: begin
                    if (eating_food) begin
                        game_over <= 1'b0;
                        gen_food <= 1'b1;
                        grow_snake <= 1'b1;
                        update_body <= 1'b0;
                        state <= STATE_IDLE;
                    end else begin
                        // Clear the cell the tail is currently leaving
                        game_over <= 1'b0;
                        gen_food <= 1'b0;
                        grow_snake <= 1'b0;
                        update_body <= 1'b0;
                        state <= STATE_IDLE;
                    end
                end

                /* TODO: add some states to check wheter the food was generated outside the snake body */
                /*TODO: Add some states for generating the Poison */
                default: begin
                    game_over <= 1'b0;
                    gen_food <= 1'b0;
                    grow_snake <= 1'b0;
                    update_body <= 1'b0;
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

  
  /*LSFR implementation for pseudo random food generation*/
  always @(posedge clk, negedge rst_n) begin
      if (~rst_n) begin
          rnd_counter <= 8'hFF; 
      end else begin
          rnd_counter <= {feedback, rnd_counter[7:1]};
      end
  end

    /*Food generation coordinates*/
  always @(posedge clk, negedge rst_n) begin
      if (~rst_n) begin
          food_x <= 6;
          food_y <= 8;
      end else begin
          if(gen_food) begin
              food_x <= rnd_counter[7:4];
              food_y <= {rnd_counter[3:1],1'b0};
          end 
      end
  end
    
    
    /*Pixel color generation on the fly based on the current cell coordinates
    and the coordinates of the snake and the food*/
    always @(*) begin
        if (!video_active) begin
            R = 2'b00; G = 2'b00; B = 2'b00;
        end else if (game_over) begin
            R = cell_x[2:1]; G =cell_x[1:0]; B = cell_y[1:0]; // Red Food
        end else if (is_body) begin
            R = 2'b00; G = 2'b11; B = 2'b00; // Green Snake
        end else if (is_food) begin
            R = 2'b11; G = 2'b00; B = 2'b00; // Red Food
        end else begin
            R = 2'b00; G = 2'b00; B = 2'b01; // Blue Background
        end
    end

    /*Parallel checker of the current cell and the content stored inside the snake body*/
    integer j;
      always @(*) begin
          is_body = 1'b0;
          for (j = 0; j < SNAKE_LENGHT; j = j + 1) begin
              if (j < tail_ptr) begin
                  if ((cell_x == snake_body[j][4:0]) && (cell_y == snake_body[j][8:5]))
                      is_body = 1'b1;
              end
          end
      end

endmodule
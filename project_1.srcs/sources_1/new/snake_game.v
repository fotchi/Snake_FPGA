//------------------------------------------------------------------------
// snake_game.v
// Grid-based Snake game logic.
//
//   Grid  : 32 columns x 24 rows   (cell = 20x20 pixels -> 640x480)
//   Body  : fixed-size shift register of MAX_LEN cells
//   Speed : one grid-step every SPEED_DIV pixel-clock ticks.
//------------------------------------------------------------------------
module snake_game #(
    parameter GRID_W    = 32,
    parameter GRID_H    = 24,
    parameter CELL      = 20,
    parameter MAX_LEN   = 64,
    parameter SPEED_DIV = 3_750_000   // @25MHz pixclk -> ~150 ms/step
) (
    input  wire        clk_pix,
    input  wire        reset,        // synchronous reset / new game
    input  wire        up, down, left, right,  // debounced button pulses

    input  wire [9:0]  hcount,
    input  wire [9:0]  vcount,
    input  wire        de,

    output reg  [7:0]  red,
    output reg  [7:0]  green,
    output reg  [7:0]  blue,

    output reg  [7:0]  score = 0,
    output reg         game_over = 0,
    output reg         eat_pulse = 0
);

    // ---------------- DECLARATIONS & PARAMETERS ------------------------
    localparam DIR_UP=2'd0, DIR_DOWN=2'd1, DIR_LEFT=2'd2, DIR_RIGHT=2'd3;
    
    // CORRECTION : Délimitation du cadre de jeu rétrécie pour éviter l'Overscan TV
    localparam WALL_TOP    = 3;  // Laisse plus de place en haut pour le texte
    localparam WALL_BOTTOM = 22; // Remonté pour éviter le bord bas
    localparam WALL_LEFT   = 1;  // Décalé de la bordure gauche
    localparam WALL_RIGHT  = 30; // Décalé de la bordure droite

    reg [1:0] dir = DIR_RIGHT, dir_next = DIR_RIGHT;

    // snake body (shift register)
    reg [5:0] snake_x [0:MAX_LEN-1];
    reg [5:0] snake_y [0:MAX_LEN-1];
    reg [6:0] length = 3;             // active segment count

    // food & randomizer
    reg [5:0] food_x = 10, food_y = 12;
    reg [16:0] lfsr = 17'h1ACE;       // pseudo-random source (non-zero seed)
    reg [5:0] safe_food_x = 20, safe_food_y = 12;
    reg       cand_overlaps;

    // timer & state variables
    reg [21:0] speed_cnt = 0;
    wire       step_tick = (speed_cnt == SPEED_DIV-1);

    integer i;
    reg [5:0] new_head_x, new_head_y;
    reg       wall_hit, self_hit;

    // ---------------- 5x7 BITMAP FONT ----------------------------------
    function [4:0] font_row;
        input [7:0] ch;
        input [2:0] r;
        reg [34:0] b;
        begin
            case (ch)
                "G": b = {5'b01110,5'b10001,5'b10000,5'b10111,5'b10001,5'b10001,5'b01110};
                "A": b = {5'b01110,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
                "M": b = {5'b10001,5'b11011,5'b10101,5'b10101,5'b10001,5'b10001,5'b10001};
                "E": b = {5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b11111};
                "O": b = {5'b01110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
                "V": b = {5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01010,5'b00100};
                "R": b = {5'b11110,5'b10001,5'b10001,5'b11110,5'b10100,5'b10010,5'b10001};
                "S": b = {5'b01111,5'b10000,5'b10000,5'b01110,5'b00001,5'b00001,5'b11110};
                "N": b = {5'b10001,5'b11001,5'b10101,5'b10011,5'b10001,5'b10001,5'b10001};
                "K": b = {5'b10001,5'b10010,5'b10100,5'b11000,5'b10100,5'b10010,5'b10001};
                "C": b = {5'b01110,5'b10001,5'b10000,5'b10000,5'b10000,5'b10001,5'b01110};
                "0": b = {5'b01110,5'b10001,5'b10011,5'b10101,5'b11001,5'b10001,5'b01110};
                "1": b = {5'b00100,5'b01100,5'b00100,5'b00100,5'b00100,5'b00100,5'b01110};
                "2": b = {5'b01110,5'b10001,5'b00001,5'b00010,5'b00100,5'b01000,5'b11111};
                "3": b = {5'b11111,5'b00010,5'b00100,5'b00010,5'b00001,5'b10001,5'b01110};
                "4": b = {5'b00010,5'b00110,5'b01010,5'b10010,5'b11111,5'b00010,5'b00010};
                "5": b = {5'b11111,5'b10000,5'b11110,5'b00001,5'b00001,5'b10001,5'b01110};
                "6": b = {5'b00110,5'b01000,5'b10000,5'b11110,5'b10001,5'b10001,5'b01110};
                "7": b = {5'b11111,5'b00001,5'b00010,5'b00100,5'b01000,5'b01000,5'b01000};
                "8": b = {5'b01110,5'b10001,5'b10001,5'b01110,5'b10001,5'b10001,5'b01110};
                "9": b = {5'b01110,5'b10001,5'b10001,5'b01111,5'b00001,5'b00010,5'b01100};
                default: b = 35'b0; // space / unknown
            endcase
            case (r)
                0: font_row = b[34:30];
                1: font_row = b[29:25];
                2: font_row = b[24:20];
                3: font_row = b[19:15];
                4: font_row = b[14:10];
                5: font_row = b[9:5];
                default: font_row = b[4:0];
            endcase
        end
    endfunction

    // ---------------- TEXT HELPERS ---------------------------------------
    function [7:0] go_char; // "GAME OVER"
        input [3:0] idx;
        begin
            case (idx)
                4'd0: go_char = "G"; 4'd1: go_char = "A"; 4'd2: go_char = "M";
                4'd3: go_char = "E"; 4'd4: go_char = " "; 4'd5: go_char = "O";
                4'd6: go_char = "V"; 4'd7: go_char = "E"; 4'd8: go_char = "R";
                default: go_char = " ";
            endcase
        end
    endfunction

    function [7:0] sn_char; // "SNAKE"
        input [2:0] idx;
        begin
            case (idx)
                3'd0: sn_char = "S"; 3'd1: sn_char = "N"; 3'd2: sn_char = "A";
                3'd3: sn_char = "K"; 3'd4: sn_char = "E";
                default: sn_char = " ";
            endcase
        end
    endfunction

    wire [7:0] sc_hundreds = "0" + (score / 100);
    wire [7:0] sc_tens     = "0" + ((score / 10) % 10);
    wire [7:0] sc_ones     = "0" + (score % 10);

    function [7:0] sc_char; // "SCORE" + 3 digits
        input [3:0] idx;
        input [7:0] h, t, o;
        begin
            case (idx)
                4'd0: sc_char = "S"; 4'd1: sc_char = "C"; 4'd2: sc_char = "O";
                4'd3: sc_char = "R"; 4'd4: sc_char = "E"; 
                4'd5: sc_char = " "; // CORRECTION : Espace bien ajouté ici
                4'd6: sc_char = h;   4'd7: sc_char = t;   4'd8: sc_char = o;
                default: sc_char = " ";
            endcase
        end
    endfunction

    // ---------------- TEXT DRAWING LOGIC ---------------------------------
    // "GAME OVER"
    localparam GO_SCALE = 3;
    localparam GO_ADV   = 6*GO_SCALE;
    localparam GO_LEN   = 9;
    localparam GO_W     = GO_LEN*GO_ADV;
    localparam GO_H     = 7*GO_SCALE;
    localparam GO_X0    = (640-GO_W)/2;
    localparam GO_Y0    = 220;

    wire in_go_box  = game_over && de && hcount>=GO_X0 && hcount<GO_X0+GO_W && vcount>=GO_Y0 && vcount<GO_Y0+GO_H;
    wire [9:0] go_relx = hcount - GO_X0;
    wire [9:0] go_rely = vcount - GO_Y0;
    wire [3:0] go_charidx = go_relx / GO_ADV;
    wire [9:0] go_within  = go_relx % GO_ADV;
    wire [2:0] go_col = go_within / GO_SCALE;
    wire [2:0] go_row = go_rely   / GO_SCALE;
    wire go_pixel = in_go_box && (go_within < 5*GO_SCALE) && font_row(go_char(go_charidx), go_row)[4-go_col];

    // "SCORE 000"
    localparam SC_SCALE = 2;
    localparam SC_ADV   = 6*SC_SCALE;
    localparam SC_LEN   = 9;  // CORRECTION : 9 caractères pour inclure l'espace
    localparam SC_X0    = 32; // CORRECTION : Décalé de la gauche (TV Overscan)
    localparam SC_Y0    = 24; // CORRECTION : Descendu (TV Overscan)

    wire in_sc_box  = de && hcount>=SC_X0 && hcount<SC_X0+SC_LEN*SC_ADV && vcount>=SC_Y0 && vcount<SC_Y0+7*SC_SCALE;
    wire [9:0] sc_relx = hcount - SC_X0;
    wire [9:0] sc_rely = vcount - SC_Y0;
    wire [3:0] sc_charidx = sc_relx / SC_ADV;
    wire [9:0] sc_within  = sc_relx % SC_ADV;
    wire [2:0] sc_col = sc_within / SC_SCALE;
    wire [2:0] sc_row = sc_rely   / SC_SCALE;
    wire sc_pixel = in_sc_box && (sc_within < 5*SC_SCALE) && font_row(sc_char(sc_charidx, sc_hundreds, sc_tens, sc_ones), sc_row)[4-sc_col];

    // "SNAKE"
    localparam SN_SCALE = 3;
    localparam SN_ADV   = 6*SN_SCALE;
    localparam SN_LEN   = 5;
    localparam SN_W     = SN_LEN*SN_ADV;
    localparam SN_X0    = (640-SN_W)/2;
    localparam SN_Y0    = 24; // CORRECTION : Descendu (TV Overscan)

    wire in_sn_box  = de && hcount>=SN_X0 && hcount<SN_X0+SN_W && vcount>=SN_Y0 && vcount<SN_Y0+7*SN_SCALE;
    wire [9:0] sn_relx = hcount - SN_X0;
    wire [9:0] sn_rely = vcount - SN_Y0;
    wire [2:0] sn_charidx = sn_relx / SN_ADV;
    wire [9:0] sn_within  = sn_relx % SN_ADV;
    wire [2:0] sn_col = sn_within / SN_SCALE;
    wire [2:0] sn_row = sn_rely   / SN_SCALE;
    wire sn_pixel = in_sn_box && (sn_within < 5*SN_SCALE) && font_row(sn_char(sn_charidx), sn_row)[4-sn_col];

// ---------------- RANDOM FOOD GENERATOR -----------------------------
    always @(posedge clk_pix) begin
        if (reset) begin
            lfsr <= 17'h1ACE; // Valeur de départ non-nulle
        end else begin
            // CORRECTION : Un vrai polynôme LFSR 17 bits (taps 17, 14) 
            // On a supprimé le "| 17'd1" qui bloquait le calcul
            lfsr <= {lfsr[15:0], lfsr[16] ^ lfsr[13]};
        end
    end

    // X jouable: de 2 à 29 (Largeur = 28)
    wire [5:0] cand_food_x = 2 + (lfsr[6:0]  % 28); 
    // Y jouable: de 4 à 21 (Hauteur = 18)
    wire [5:0] cand_food_y = 4 + (lfsr[13:7] % 18); 

    always @(*) begin
        cand_overlaps = 1'b0;
        for (i = 0; i < MAX_LEN; i = i + 1)
            if (i < length && snake_x[i] == cand_food_x && snake_y[i] == cand_food_y)
                cand_overlaps = 1'b1;
    end

    always @(posedge clk_pix) begin
        if (!cand_overlaps)
            {safe_food_x, safe_food_y} <= {cand_food_x, cand_food_y};
    end
    // ---------------- CONTROLLER & GAME LOGIC ---------------------------
    always @(posedge clk_pix) begin
        if (reset) begin
            dir_next <= DIR_RIGHT;
        end else begin
            if (up    && dir != DIR_DOWN)  dir_next <= DIR_UP;
            if (down  && dir != DIR_UP)    dir_next <= DIR_DOWN;
            if (left  && dir != DIR_RIGHT) dir_next <= DIR_LEFT;
            if (right && dir != DIR_LEFT)  dir_next <= DIR_RIGHT;
        end
    end

    always @(posedge clk_pix) begin
        if (reset) begin
            speed_cnt <= 0;
            dir       <= DIR_RIGHT;
            length    <= 3;
            score     <= 0;
            game_over <= 0;
            food_x    <= 10;
            food_y    <= 12;
            for (i = 0; i < MAX_LEN; i = i + 1) begin
                snake_x[i] <= (i < 10) ? (15 - i[5:0]) : 6'd1;
                snake_y[i] <= 12;
            end
        end else if (!game_over) begin
            eat_pulse <= 1'b0;
            if (speed_cnt == SPEED_DIV-1)
                speed_cnt <= 0;
            else
                speed_cnt <= speed_cnt + 1;

            if (step_tick) begin
                dir <= dir_next;

                // compute new head position
                new_head_x = snake_x[0];
                new_head_y = snake_y[0];
                case (dir_next)
                    DIR_UP:    new_head_y = snake_y[0] - 1;
                    DIR_DOWN:  new_head_y = snake_y[0] + 1;
                    DIR_LEFT:  new_head_x = snake_x[0] - 1;
                    DIR_RIGHT: new_head_x = snake_x[0] + 1;
                endcase

                // wall collision : tapé le cadre spécifié
                wall_hit = (new_head_x <= WALL_LEFT) || (new_head_x >= WALL_RIGHT) ||
                           (new_head_y <= WALL_TOP)  || (new_head_y >= WALL_BOTTOM);

                // self collision
                self_hit = 1'b0;
                for (i = 1; i < MAX_LEN; i = i + 1)
                    if (i < length && snake_x[i] == new_head_x && snake_y[i] == new_head_y)
                        self_hit = 1'b1;

                if (wall_hit || self_hit) begin
                    game_over <= 1'b1;
                end else begin
                    // shift body
                    for (i = MAX_LEN-1; i > 0; i = i - 1) begin
                        snake_x[i] <= snake_x[i-1];
                        snake_y[i] <= snake_y[i-1];
                    end
                    snake_x[0] <= new_head_x;
                    snake_y[0] <= new_head_y;

                    // eat food
                    if (new_head_x == food_x && new_head_y == food_y) begin
                        if (length < MAX_LEN) length <= length + 1;
                        score <= score + 1;
                        food_x <= safe_food_x;
                        food_y <= safe_food_y;
                        eat_pulse <= 1'b1;
                    end
                end
            end
        end
    end

    // ---------------- PIXEL RENDERING (COMBINATIONAL) -------------------
    wire [5:0] col = hcount / CELL;
    wire [5:0] row = vcount / CELL;
    reg        on_snake, on_food, on_head;
    reg        snake_seg_alt;

    // Détermine si le pixel est sur un mur OU à l'intérieur de la zone de jeu
    wire is_wall_pixel = (row == WALL_TOP) || (row == WALL_BOTTOM) || 
                         ((col == WALL_LEFT || col == WALL_RIGHT) && (row >= WALL_TOP && row <= WALL_BOTTOM));
    wire in_play_area  = (row > WALL_TOP) && (row < WALL_BOTTOM) && (col > WALL_LEFT) && (col < WALL_RIGHT);

    // Bords des briques pour effet visuel des murs
    wire [4:0] sub_x = hcount % CELL;
    wire [4:0] sub_y = vcount % CELL;
    wire       wall_edge = (sub_x < 2) || (sub_x >= CELL-2) || (sub_y < 2) || (sub_y >= CELL-2);

    wire       checker = col[0] ^ row[0];

    always @(*) begin
        on_snake = 1'b0;
        snake_seg_alt = 1'b0;
        on_head  = (col == snake_x[0] && row == snake_y[0]);
        for (i = 0; i < MAX_LEN; i = i + 1)
            if (i < length && snake_x[i] == col && snake_y[i] == row) begin
                on_snake = 1'b1;
                snake_seg_alt = i[0];
            end
        on_food = (col == food_x && row == food_y);
    end

    // Priorité d'affichage finale
    always @(*) begin
        if (!de) begin
            {red, green, blue} = 24'h000000;
        end else if (go_pixel) begin
            {red, green, blue} = 24'hFFFFFF;   // GAME OVER text (White)
        end else if (sn_pixel) begin
            {red, green, blue} = 24'h00FF00;   // SNAKE text (Green)
        end else if (sc_pixel) begin
            {red, green, blue} = 24'hFFFFFF;   // SCORE text (White)
        end else if (game_over && in_play_area) begin
            {red, green, blue} = 24'h150000;   // Fond rouge sombre dans l'arène lors d'une défaite
        end else if (is_wall_pixel) begin
            {red, green, blue} = wall_edge ? 24'h13263D : 24'h1E5C99; // Briques bleues
        end else if (on_head && in_play_area) begin
            {red, green, blue} = 24'hFFFF00;   // Tête jaune
        end else if (on_snake && in_play_area) begin
            {red, green, blue} = snake_seg_alt ? 24'h00AA00 : 24'h00FF00; // Corps vert texturé
        end else if (on_food && in_play_area) begin
            {red, green, blue} = 24'hFF0000;   // Pomme rouge
        end else if (in_play_area) begin
            {red, green, blue} = checker ? 24'h141414 : 24'h0C0C0C; // Damier de l'arène
        end else begin
            {red, green, blue} = 24'h050508;   // Fond très sombre pour la zone d'en-tête
        end
    end

endmodule
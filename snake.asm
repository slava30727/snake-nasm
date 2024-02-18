section .bss
    console resd 6
    game    resd 9

section .data
    game_name       db "Snake Game", 0
    field_size      dd 30
    cls             db "cls", 0
    game_over_msg   db "Game over!", 0
    
    error_msg       db "Error code: %d", 10, 0

section .text
    global main

extern calloc, free, memset, getchar, printf, system, rand
extern SetConsoleTitleA@4, GetStdHandle@4, WriteConsoleOutputA@20, Sleep@4
extern GetAsyncKeyState@4, GetLastError@0

%define false 0
%define true  1

%define Cell_None 0
%define Cell_Snake 1
%define Cell_Food 2

%define Direction_Up 0
%define Direction_Down 3
%define Direction_Left 2
%define Direction_Right 1
%define Direction_DEFAULT Direction_Up

%define BACKGROUND_INTENSITY  0x0080
%define BACKGROUND_RED        0x0040
%define BACKGROUND_GREEN      0x0020
%define BACKGROUND_BLUE       0x0010
%define FOREGROUND_INTENSITY  0x0008
%define FOREGROUND_RED        0x0004
%define FOREGROUND_GREEN      0x0002
%define FOREGROUND_BLUE       0x0001

%define STD_OUTPUT_HANDLE -11

%define VK_ESCAPE       0x1B
%define VK_UP           0x26
%define VK_DOWN         0x28
%define VK_LEFT         0x25
%define VK_RIGHT        0x27



main:
    push ebp
    mov ebp, esp

    ; var [ebp-12] tmp_field: GameField
    sub esp, 12

    ; system("cls")
    push cls
    call system
    add esp, 4
    
    ; SetConcoleTitleA("Snake Game");
    push game_name
    call SetConsoleTitleA@4

    ; console = Console_new(2 * field_size, field_size, 10, 5)
    push 5
    push 10
    mov eax, [field_size]
    push eax
    shl eax, 1
    push eax
    push console
    call Console_new

    ; tmp_field = GameField_new(field_size, field_size)
    push dword [field_size]
    push dword [field_size]
    lea eax, [ebp-12]
    push eax
    call GameField_new

    ; game = Game_new(tmp_field)
    push dword [ebp-12+8]
    push dword [ebp-12+4]
    push dword [ebp-12+0]
    push game
    call Game_new

    ; loop {
main_loop_start:
    ;     Sleep(100)
    push 100
    call Sleep@4

    ; if is_key_pressed(VK_ESCAPE) { break }
    mov ecx, VK_ESCAPE
    call is_key_pressed
    cmp eax, 0
    jnz main_loop_end

    ; if is_key_pressed(VK_UP) && Direction_Down != game.snake_direction
    mov ecx, VK_UP
    call is_key_pressed
    cmp eax, 0
    jz main_loop_up_not_pressed
    cmp [game+28], dword Direction_Down
    je main_loop_up_not_pressed

    ;     game.snake_direction = Direction_Up
    mov [game+28], dword Direction_Up

main_loop_up_not_pressed:
    ; if is_key_pressed(VK_DOWN) && Direction_Up != game.snake_direction
    mov ecx, VK_DOWN
    call is_key_pressed
    cmp eax, 0
    jz main_loop_down_not_pressed
    cmp [game+28], dword Direction_Up
    je main_loop_down_not_pressed

    ;     game.snake_direction = Direction_Down
    mov [game+28], dword Direction_Down

main_loop_down_not_pressed:
    ; if is_key_pressed(VK_LEFT) && Direction_Right != game.snake_direction
    mov ecx, VK_LEFT
    call is_key_pressed
    cmp eax, 0
    jz main_loop_left_not_pressed
    cmp [game+28], dword Direction_Right
    je main_loop_left_not_pressed

    ;     game.snake_direction = Direction_Left
    mov [game+28], dword Direction_Left

main_loop_left_not_pressed:
    ; if is_key_pressed(VK_RIGHT) && Direction_Left != game.snake_direction
    mov ecx, VK_RIGHT
    call is_key_pressed
    cmp eax, 0
    jz main_loop_right_not_pressed
    cmp [game+28], dword Direction_Left
    je main_loop_right_not_pressed

    ;     game.snake_direction = Direction_Right
    mov [game+28], dword Direction_Right

main_loop_right_not_pressed:
    ; if (game.update()) {
    push game
    call Game_update
    cmp eax, 0
    jz main_loop_game_is_not_over

    ;     printf("Game over!")
    push game_over_msg
    call printf
    add esp, 4

    ;     getchar()
    call getchar

    ;     break
    jmp main_loop_end

    ; }
main_loop_game_is_not_over:
    ; graw_game(&game, &console)
    push console
    push game
    call draw_game

    ; console.write()
    push console
    call Console_write

    ; } // loop
    jmp main_loop_start

main_loop_end:

    ; system("cls")
    push cls
    call system
    add esp, 4

    ; Game_free(&game)
    push game
    call Game_free

    ; Console_free(&console)
    push console
    call Console_free

    ; restore stack
    add esp, 12
    
    xor eax, eax
    
    pop ebp
    ret



; #[fastcall]
; fn mod([ecx] denom: int, [edx] num: int) -> int [eax]
mod:
    ; result = [edx] ([edx] ([eax] num % [ecx] denom) + denom) % denom
    mov eax, edx
    cdq
    idiv ecx
    add edx, ecx
    mov eax, edx
    cdq
    idiv ecx
    mov eax, edx
    ret



; #[fastcall]
; fn is_key_pressed([ecx] key: uint) -> bool [eax]
is_key_pressed:
    ; ax = GetAsyncKeyState(key)
    push ecx
    call GetAsyncKeyState@4

    ; ax &= 1 << 15
    and ax, 1 << 15

    ; return 0 != ax
    cmp ax, 0
    setnz al
    movzx eax, al

    ret



; #[stdcall]
; fn handle_winapi_error()
handle_winapi_error:
    call GetLastError@0
    push eax
    push error_msg
    call printf
    add esp, 8
    ret




; Console :: struct {
;     handle: HANDLE,
;     width: usize,
;     height: usize,
;     offset_x: usize,
;     offset_y: usize,
;     buf: *CHAR_INFO,
; }

; #[stdcall]
; fn Console_new(
;     [ebp+12] width: uint, [ebp+16] height: uint,
;     [ebp+20] offset_x: uint, [ebp+24] offset_y: uint,
; ) -> Console [ebp+8];
Console_new:
    push ebp
    mov ebp, esp

    push ebx
    mov ebx, [ebp+8]

    ; result.handle = GetStdHandle(STD_OUTPUT_HANDLE);
    push STD_OUTPUT_HANDLE
    call GetStdHandle@4
    mov [ebx+0], eax

    ; result.width = width
    mov eax, [ebp+12]
    mov [ebx+4], eax

    ; result.height = height
    mov eax, [ebp+16]
    mov [ebx+8], eax

    ; result.offset_x = offset_x
    mov eax, [ebp+20]
    mov [ebx+12], eax

    ; result.offset_y = offset_y
    mov eax, [ebp+24]
    mov [ebx+16], eax

    ; result.buf = calloc(width * height, sizeof(CHAR_INFO))
    mov eax, [ebp+12]
    mov edx, [ebp+16]
    mul edx
    push 4
    push eax
    call calloc
    add esp, 8
    mov ebx, [ebp+8]
    mov [ebx+20], eax

    pop ebx
    pop ebp
    ret 20


; #[stdcall]
; fn Console_free([ebp+8] self: *Console);
Console_free:
    push ebp
    mov ebp, esp

    push ebx
    mov ebx, [ebp+8]
    
    ; free(self->buf);
    push dword [ebx+20]
    call free
    add esp, 4

    ; *self = default
    ; memset(self, 0, sizeof(Console));
    push 24
    push 0
    push ebx
    call memset
    add esp, 12

    pop ebx
    pop ebp
    ret 4


; #[stdcall]
; fn Console_write([ebp+8] self: *Console) -> bool [eax];
Console_write:
    push ebp
    mov ebp, esp

    ; save self
    push ebx
    mov ebx, [ebp+8]

    ; var [ebp-8] rect_pos: COORD
    ; var [ebp-16] write_area: SMALL_RECT
    ; var [ebp-20] buffer_size: COORD
    sub esp, 16

    ; rect_pos = {}
    mov [ebp-8], dword 0

    ; write_area.Left = self->offset_x
    mov eax, [ebx+12]
    mov [ebp-16+0], ax

    ; write_area.Right = self->offset_x + self->width - 1
    add eax, [ebx+4]
    dec eax
    mov [ebp-16+4], ax

    ; write_area.Top = self->offset_y
    mov eax, [ebx+16]
    mov [ebp-16+2], ax

    ; write_area.Bottom = self->offset_y + self->height - 1
    add eax, [ebx+8]
    dec eax
    mov [ebp-16+6], ax

    ; buffer_size.X = self->width
    mov eax, [ebx+4]
    mov [ebp-20+0], ax

    ; buffer_size.Y = self->height
    mov eax, [ebx+8]
    mov [ebp-20+2], ax
    
    mov eax, [ebp-16+0]
    mov edx, [ebp-16+4]
    mov ecx, [ebp-20]

    ; WriteConsoleOutputA(
    ;     self->handle, self->buf, buffer_size, { 0, 0 }, &write_area
    ; )
    lea eax, [ebp-16]
    push eax
    push 0
    push dword [ebp-20]
    push dword [ebx+20]
    push dword [ebx+0]
    call WriteConsoleOutputA@20
    
    cmp eax, 0
    jne Console_write_write_succcess
    call handle_winapi_error
    
Console_write_write_succcess:
   
    add esp, 16

    pop ebx
    pop ebp
    ret 4



%define Direction_opposite(reg) \
    not reg \
    and reg, 3


; #[stdcall]
; fn Direction_transform(
;     [ebp+8] self: Direction, [ebp+12] pos: Vec2,
; ) -> Vec2 [edx:eax]
Direction_transform:
    push ebp
    mov ebp, esp

    ; result = pos
    mov edx, [ebp+12+0]
    mov eax, [ebp+12+4]
    
    cmp [ebp+8], dword Direction_Up
    jne Direction_transform_not_up
    dec eax
    pop ebp
    ret 12

Direction_transform_not_up:
    cmp [ebp+8], dword Direction_Down
    jne Direction_transform_not_down
    inc eax
    pop ebp
    ret 12

Direction_transform_not_down:
    cmp [ebp+8], dword Direction_Left
    jne Direction_transform_not_left
    dec edx
    pop ebp
    ret 12

Direction_transform_not_left:
    inc edx
    pop ebp
    ret 12



; Snake :: struct {
;     directions: *u8,
;     len: uint,
;     pos: Vec2,
; }

; #[stdcall]
; fn Snake_new([ebp+12] pos: Vec2, [ebp+20] n_cells: usize) -> Snake [[ebp+8]];
Snake_new:
    push ebp
    mov ebp, esp

    push ebx
    mov ebx, [ebp+8]

    ; result.directions = calloc(n_cells, sizeof(u8));
    push 1
    push dword [ebp+20]
    call calloc
    add esp, 8
    mov [ebx+0], eax

    ; result.len = 4
    mov [ebx+4], dword 4

    ; result.pos = pos
    mov eax, [ebp+12+0]
    mov [ebx+8+0], eax
    mov eax, [ebp+12+4]
    mov [ebx+8+4], eax

    ; memset(result.directions, Directions_Down, sizeof(u8) * n_cells);
    push dword [ebp+20]
    push Direction_Down
    push dword [ebx+0]
    call memset
    add esp, 12

    pop ebx
    pop ebp
    ret 16


; #[stdcall]
; fn Snake_move(
;     [ebp+8] self: *Snake,
;     [ebp+12] direction: Direction,
;     [ebp+16] do_grow: bool,
; )
Snake_move:
    push ebp
    mov ebp, esp

    push ebx
    mov ebx, [ebp+8]

    ; self->pos = direction.transform(self->pos)
    push dword [ebx+8+4]
    push dword [ebx+8+0]
    push dword [ebp+12]
    call Direction_transform
    mov [ebx+8+0], edx
    mov [ebx+8+4], eax

    ; direction = direction.opposite();
    not dword [ebp+12]
    and [ebp+12], dword 3

    ; self->len += do_grow
    mov eax, [ebp+16]
    add [ebx+4], eax

    ; ecx i = 0
    xor ecx, ecx

Snake_move_loop_start:
    ; i < self->len
    cmp ecx, [ebx+4]
    jge Snake_move_loop_end

    ; swap(self->directions[i], direction)
    mov eax, [ebp+12]
    mov edx, [ebx+0]
    xchg al, [edx+ecx]
    mov [ebp+12], eax

    ; ++i
    inc ecx
    jmp Snake_move_loop_start

Snake_move_loop_end:

    pop ebx
    pop ebp
    ret 12


; #[stdcall]
; fn Snake_get_tail_pos([ebp+8] self: *Snake) -> Vec2 [edx:eax]
Snake_get_tail_pos:
    push ebp
    mov ebp, esp

    push ebx
    mov ebx, [ebp+8]

    ; var [ebp-12] result: Vec2
    ; var [ebp-16] i: uint
    sub esp, 12

    ; result = self->pos
    mov eax, [ebx+8+0]
    mov [ebp-12+0], eax
    mov eax, [ebx+8+4]
    mov [ebp-12+4], eax

    ; [ebp-16] i = 0
    mov [ebp-16], dword 0

Snake_get_tail_pos_loop_start:
    ; i < self->len
    mov ecx, [ebp-16]
    cmp ecx, [ebx+4]
    jge Snake_get_tail_pos_loop_end

    ; result = self->directions[i].transform(result)
    push dword [ebp-12+4]
    push dword [ebp-12+0]
    mov edx, [ebx+0]
    mov dl, [edx+ecx]
    movzx edx, dl
    push edx
    call Direction_transform
    mov [ebp-12+0], edx
    mov [ebp-12+4], eax

    ; ++i
    inc dword [ebp-16]
    jmp Snake_get_tail_pos_loop_start

Snake_get_tail_pos_loop_end:

    ; restore stack
    add esp, 12

    ; return result
    mov edx, [ebp-12+0]
    mov eax, [ebp-12+4]

    pop ebx
    pop ebp
    ret 4


; #[stdcall]
; fn Snake_free([ebp+8] self: *Snake)
Snake_free:
    push ebp
    mov ebp, esp

    push ebx
    mov ebx, [ebp+8]

    ; free(self->directions)
    push dword [ebx+0]
    call free
    add esp, 4

    ; *self = Snake_DEFAULT
    mov [ebx+0], dword 0
    mov [ebx+4], dword 0
    mov [ebx+8], dword 0
    mov [ebx+12], dword 0

    pop ebx
    pop ebp
    ret 4



; GameField :: struct {
;     width: uint,
;     height: uint,
;     buf: *u8,
; }

; #[stdcall]
; fn GameField_new([ebp+12] width: uint, [ebp+16] height: uint)
;     -> GameField [[ebp+8]]
GameField_new:
    push ebp
    mov ebp, esp

    push ebx
    mov ebx, [ebp+8]

    ; result.buf = calloc(width * height, sizeof(u8))
    mov eax, [ebp+12]
    mov edx, [ebp+16]
    mul edx
    push 1
    push eax
    call calloc
    add esp, 8
    mov [ebx+8], eax

    ; result.width = width
    mov eax, [ebp+12]
    mov [ebx+0], eax

    ; result.height = height
    mov eax, [ebp+16]
    mov [ebx+4], eax

    pop ebx
    pop ebp
    ret 12


; #[stdcall]
; fn GameField_free([ebp+8] self: *GameField)
GameField_free:
    push ebp
    mov ebp, esp

    push ebx
    mov ebx, [ebp+8]

    ; free(self->buf)
    push dword [ebx+8]
    call free
    add esp, 4

    ; *self = default
    mov [ebx+0], dword 0
    mov [ebx+4], dword 0
    mov [ebx+8], dword 0

    pop ebx
    pop ebp
    ret 4


; #[stdcall]
; fn GameField_generate_food([ebp+8] self: *GameField)
GameField_generate_food:
    push ebp
    mov ebp, esp

    push ebx
    mov ebx, [ebp+8]

    ; var [ebp-8] none_count: uint
    ; var [ebp-12] n_cells: uint
    ; var [ebp-16] random_index: uint
    ; var [ebp-20] j: uint
    sub esp, 16

    ; none_count = 0
    mov [ebp-8], dword 0

    ; n_cells = self->width * self->height
    mov eax, [ebx+0]
    mov edx, [ebx+4]
    mul edx
    mov [ebp-12], eax

    ; ecx i = 0
    xor ecx, ecx

GameField_generate_food_first_loop_start:
    ; i < n_cells
    cmp ecx, [ebp-12]
    jge GameField_generate_food_first_loop_end

    ; self->buf[i] == Cell_None
    mov eax, [ebx+8]
    cmp [eax+ecx], byte Cell_None
    sete al
    movzx eax, al
    
    ; none_count += eax
    add [ebp-8], eax

    ; ++i
    inc ecx
    jmp GameField_generate_food_first_loop_start

GameField_generate_food_first_loop_end:

    ; if 0 == none_count { return }
    cmp [ebp-8], dword 0
    je GameField_generate_food_end

    ; random_index = rand() % none_count
    call rand
    cdq
    mov ecx, [ebp-8]
    div ecx
    mov [ebp-16], edx

    ; ecx i = 0, [ebp-20] j = 0
    xor ecx, ecx
    mov [ebp-20], dword 0

GameField_generate_food_second_loop_start:
    ; i < n_cells
    cmp ecx, [ebp-12]
    jge GameField_generate_food_second_loop_end

    ; dl := random_index == j
    mov eax, [ebp-20]
    sub eax, [ebp-16]
    setz dl

    ; dh = self->buf[i] == Cell_None
    mov eax, [ebx+8]
    cmp [eax+ecx], byte Cell_None
    sete dh

    ; if (dl && dh) {
    ;     self->buf[i] = Cell_Food;
    ;     break;
    ; }
    and dl, dh
    mov edx, [ebx+8]
    jz GameField_generate_food_second_loop_final
    mov [edx+ecx], byte Cell_Food
    jmp GameField_generate_food_second_loop_end

GameField_generate_food_second_loop_final:
    ; j += Cell_None == self->buf[i]
    cmp [edx+ecx], byte Cell_None
    sete al
    movzx eax, al
    add [ebp-20], eax

    ; ++i
    inc ecx
    jmp GameField_generate_food_second_loop_start

GameField_generate_food_second_loop_end:

GameField_generate_food_end:
    add esp, 16

    pop ebx
    pop ebp
    ret 4



; Game :: struct {
;     field: GameField,            // 12 bytes
;     snake: Snake,                // 16 bytes
;     snake_direction: Direction,  // 4 bytes
;     ate_food: bool,              // 4 bytes
; }

; #[stdcall]
; fn Game_new([ebp+12] field: GameField) -> Game [[ebp+8]]
Game_new:
    push ebp
    mov ebp, esp

    push ebx
    mov ebx, [ebp+8]

    ; result.field = field
    mov eax, [ebp+12+0]
    mov [ebx+0+0], eax
    mov eax, [ebp+12+4]
    mov [ebx+0+4], eax
    mov eax, [ebp+12+8]
    mov [ebx+0+8], eax

    ; result.snake_direction = Direction_DEFAULT
    mov [ebx+28], dword Direction_DEFAULT

    ; result.ate_food = false
    mov [ebx+32], dword false

    ; result.snake = Snake_new(
    ;     Vec2 { x: field.width >> 1, y: field.height >> 1 },
    ;     field.width * field.height
    ; )
    mov edx, [ebp+12+0]
    mov eax, [ebp+12+4]
    mul edx
    push eax
    mov eax, [ebp+12+4]
    shr eax, 1
    push eax
    mov eax, [ebp+12+0]
    shr eax, 1
    push eax
    lea eax, [ebx+12]
    push eax
    call Snake_new

    ; result.field.buf[0] = Cell_Food
    mov eax, [ebx+0+8]
    mov [eax+0], byte Cell_Food

    pop ebx
    pop ebp
    ret 16


; #[stdcall]
; fn Game_free([ebp+8] self: *Game)
Game_free:
    push ebp
    mov ebp, esp

    push ebx
    mov ebx, [ebp+8]

    ; GameField_free(&self->field)
    push ebx
    call GameField_free

    ; Snake_free(&self->snake)
    lea eax, [ebx+12]
    push eax
    call Snake_free

    ; *self = default <=> memset(self, 0, sizeof(*self))
    push 36
    push 0
    push ebx
    call memset
    add esp, 12

    pop ebx
    pop eax
    ret 4


; #[stdcall]
; fn Game_update([ebp+8] self: *Game) -> bool [eax]
Game_update:
    push ebp
    mov ebp, esp

    push ebx
    mov ebx, [ebp+8]

    ; var [ebp-12] pos: Vec2
    sub esp, 8

    ; pos = self->snake.get_tail_pos()
    lea eax, [ebx+12]
    push eax
    call Snake_get_tail_pos
    mov [ebp-12+0], edx
    mov [ebp-12+4], eax

    ; pos.x = mod(self->field.width, pos.x)
    mov edx, [ebp-12+0]
    mov ecx, [ebx+0+0]
    call mod
    mov [ebp-12+0], eax

    ; pos.y = mod(self->field.height, pos.y)
    mov edx, [ebp-12+4]
    mov ecx, [ebx+0+4]
    call mod
    mov [ebp-12+4], eax

    ; if (self->ate_food == false) {
    cmp [ebx+32], dword false
    jne Game_update_not_ate

    ; self->field.buf[pos.x + self->field.width * pos.y] = Cell_None
    mov edx, [ebx+0+0]
    mov eax, [ebp-12+4]
    mul edx
    add eax, [ebp-12+0]
    mov edx, [ebx+0+8]
    mov [edx+eax], byte Cell_None

Game_update_not_ate:
    ; self->snake.move(self->snake_direction, self->ate_food)
    push dword [ebx+32]
    push dword [ebx+28]
    lea eax, [ebx+12]
    push eax
    call Snake_move

    ; pos.x = mod(self->field.width, self->snake.pos.x)
    mov ecx, [ebx+0+0]
    mov edx, [ebx+12+8+0]
    call mod
    mov [ebp-12+0], eax

    ; pos.y = mod(self->field.height, self->snake.pos.y)
    mov ecx, [ebx+0+4]
    mov edx, [ebx+12+8+4]
    call mod
    mov [ebp-12+4], eax

    ; if (Cell_Snake == self->field.buf[pos.x + self->field.width * pos.y]) {
    ;     return true;
    ; }
    mov edx, [ebx+0+0]
    mov eax, [ebp-12+4]
    mul edx
    add eax, [ebp-12+0]
    mov ecx, [ebx+0+8]
    add ecx, eax
    cmp [ecx], byte Cell_Snake
    mov eax, true
    je Game_update_return

    ; self->ate_food = [ecx] == Cell_Food
    cmp [ecx], byte Cell_Food
    sete al
    movzx eax, al
    mov [ebx+32], eax
    
    ; [ecx] = Cell_Snake
    mov [ecx], byte Cell_Snake

    ; if (self->ate_food) { self->field.generate_food() }
    jne Game_update_return_false
    push ebx
    call GameField_generate_food

Game_update_return_false:
    xor eax, eax

Game_update_return:
    ; restore stack
    add esp, 8

    pop ebx
    pop ebp
    ret 4


; #[stdcall]
; fn draw_game_at(
;     [ebp+8] game: *Game, [ebp+12] console: *Console,
;     [ebp+16] x: uint, [ebp+20] y: uint,
; )
draw_game_at:
    push ebp
    mov ebp, esp

    push ebx
    mov ebx, [ebp+8]

    ; var [ebp-8] symbol: char
    ; var [ebp-12] flags: uint
    sub esp, 8

    ; eax = game->field.buf[x + game->field.width * y]
    mov eax, [ebx+0+0]
    mov edx, [ebp+20]
    mul edx
    add eax, [ebp+16]
    mov edx, [ebx+0+8]
    mov al, [edx+eax]
    movzx eax, al

    ; flags = 0
    mov [ebp-12], dword 0

    ; switch (eax) {
    push draw_game_at_case_Cell_Food   ; [esp+8]
    push draw_game_at_case_Cell_Snake  ; [esp+4]
    push draw_game_at_case_Cell_None   ; [esp]
    cmp eax, Cell_Food
    jg draw_game_at_switch_end
    mov ecx, [esp+4*eax]
    jmp ecx

draw_game_at_case_Cell_None:
    ;     case Cell_None => symbol = ' ',
    mov [ebp-8], dword " "
    jmp draw_game_at_switch_end

draw_game_at_case_Cell_Snake:
    ;     case Cell_Snake => {
    ;         symbol = "&";
    ;         flags |= FOREGROUND_GREEN | BACKGROUND_BLUE | BACKGROUND_GREEN;
    ;     },
    mov [ebp-8], dword "&"
    or [ebp-12], dword FOREGROUND_GREEN | BACKGROUND_BLUE | BACKGROUND_GREEN
    jmp draw_game_at_switch_end
    
draw_game_at_case_Cell_Food:
    ;     case Cell_Food => {
    ;         symbol = '0';
    ;         flags |= FOREGROUND_RED | BACKGROUND_RED | BACKGROUND_INTENSITY;
    ;     },
    mov [ebp-8], dword "0"
    or [ebp-12], dword FOREGROUND_RED | BACKGROUND_RED | BACKGROUND_INTENSITY

draw_game_at_switch_end:
    ; }
    add esp, 12

    ; if x == 0 { goto draw_outline }
    mov eax, [ebp+16]
    cmp eax, 0
    je draw_game_at_draw_outline

    ; if x + 1 == game->field.width { goto draw_outline }
    inc eax
    cmp eax, [ebx+0+0]
    je draw_game_at_draw_outline

    ; if y == 0 { goto draw_outline }
    mov eax, [ebp+20]
    cmp eax, 0
    je draw_game_at_draw_outline

    ; if y + 1 == game->field.height
    inc eax
    cmp eax, [ebx+0+4]
    je draw_game_at_draw_outline

    ; skip draw_outline
    jmp draw_game_at_draw_outline_end

draw_game_at_draw_outline:
    ; edx = flags
    mov edx, [ebp-12]

    ; flags ^= BACKGROUND_RED | BACKGROUND_GREEN | BACKGROUND_BLUE
    xor edx, BACKGROUND_RED | BACKGROUND_GREEN | BACKGROUND_BLUE

    ; flags |= BACKGROUND_INTENSITY
    or edx, BACKGROUND_INTENSITY

    ; flags ^= BACKGROUND_INTENSITY;
    xor edx, BACKGROUND_INTENSITY

    ; flags ^= FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE;
    xor edx, FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE
    
    ; flags = edx
    mov [ebp-12], edx

draw_game_at_draw_outline_end:
    ; ecx = console->buf + 8 * x + 4 * console->width * y
    mov ecx, [ebp+12]
    mov edx, [ecx+4]
    mov eax, [ebp+20]
    mul edx
    shl eax, 2
    mov edx, [ebp+16]
    mov ecx, [ecx+20]
    add ecx, eax
    lea ecx, [ecx+8*edx]

    ; ecx[0].Char.AsciiChar = ecx[1].Char.AsciiChar = symbol
    mov eax, [ebp-8]
    mov [ecx+0+0], ax
    mov [ecx+4+0], ax

    ; ecx[0].Attributes = ecx[1].Attributes = flags
    mov eax, [ebp-12]
    mov [ecx+0+2], ax
    mov [ecx+4+2], ax

    ; restore stack
    add esp, 8

    pop ebx
    pop ebp
    ret 16


; #[stdcall]
; fn draw_game([ebp+8] game: *Game, [ebp+12] console: *Console)
draw_game:
    push ebp
    mov ebp, esp

    push ebx
    mov ebx, [ebp+8]

    ; var [ebp-8] x: uint
    ; var [ebp-12] y: uint
    ; var [ebp-20] pos: Vec2
    sub esp, 16

    ; x = 0
    mov [ebp-8], dword 0

draw_game_loop_x_start:
    ; x < game->field.width
    mov ecx, [ebp-8]
    cmp ecx, [ebx+0+0]
    jge draw_game_loop_x_end

        ; y = 0
        mov [ebp-12], dword 0

    draw_game_loop_y_start:
        ; y < game->field.height
        mov ecx, [ebp-12]
        cmp ecx, [ebx+0+4]
        jge draw_game_loop_y_end

        ; draw_game_at(game, console, x, y)
        push ecx
        push dword [ebp-8]
        push dword [ebp+12]
        push ebx
        call draw_game_at

        ; ++y
        inc dword [ebp-12]
        jmp draw_game_loop_y_start

    draw_game_loop_y_end:

    ; ++x
    inc dword [ebp-8]
    jmp draw_game_loop_x_start

draw_game_loop_x_end:

    ; pos = game->snake.pos
    mov eax, [ebx+12+8+0]
    mov [ebp-20+0], eax
    mov eax, [ebx+12+8+4]
    mov [ebp-20+4], eax

    ; pos.x = mod(game->field.width, pos.x)
    mov ecx, [ebx+0+0]
    mov edx, [ebp-20+0]
    call mod
    mov [ebp-20+0], eax

    ; pos.y = mod(game->field.height, pos.y)
    mov ecx, [ebx+0+4]
    mov edx, [ebp-20+4]
    call mod
    mov [ebp-20+4], eax

    ; ecx = console->buf + 8 * pos.x + 4 * console->width * pos.y
    mov ecx, [ebp+12]
    mov eax, [ecx+4]
    mov edx, [ebp-20+4]
    mul edx
    shl eax, 2
    mov edx, [ebp-20+0]
    shl edx, 3
    add eax, edx
    mov ecx, [ecx+20]
    add ecx, eax

    ; ecx[0].Char.AsciiChar = ecx[1].Char.AsciiChar = '#'
    mov [ecx+0+0+0], word "#"
    mov [ecx+4+0+0], word "#"

    ; pos = game->snake.get_tail_pos()
    lea eax, [ebx+12]
    push eax
    call Snake_get_tail_pos
    mov [ebp-20+0], edx
    mov [ebp-20+4], eax

    ; pos.x = mod(game->field.width, pos.x)
    mov ecx, [ebx+0+0]
    mov edx, [ebp-20+0]
    call mod
    mov [ebp-20+0], eax

    ; pos.y = mod(game->field.height, pos.y)
    mov ecx, [ebx+0+4]
    mov edx, [ebp-20+4]
    call mod
    mov [ebp-20+4], eax

    ; ecx = console->buf + 8 * pos.x + 4 * console->width * pos.y
    mov ecx, [ebp+12]
    mov eax, [ecx+4]
    mov edx, [ebp-20+4]
    mul edx
    shl eax, 2
    mov edx, [ebp-20+0]
    shl edx, 3
    add eax, edx
    mov ecx, [ecx+20]
    add ecx, eax

    ; ecx[0].Char.AsciiChar = ecx[1].Char.AsciiChar = '%'
    mov [ecx+0+0+0], word "%"
    mov [ecx+4+0+0], word "%"

    ; restore stack
    add esp, 16

    pop ebx
    pop ebp
    ret 8
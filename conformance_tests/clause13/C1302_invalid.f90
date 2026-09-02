! C1302 (R1303) The optional comma shall not be omitted except (P before
! F/E/EN/ES/EX/D/G, before an unrepeated slash, after a slash, around a colon).
subroutine c1302_two_data_descs()
    implicit none
    character(40) :: buf
    write(buf, '(I2I2)') 1, 2   ! {error C1302 data-data}
end subroutine
subroutine c1302_p_then_i()
    implicit none
    character(40) :: buf
    write(buf, '(1PI4)') 1   ! {error C1302 p-then-i}
end subroutine
subroutine c1302_repeated_slash()
    implicit none
    character(40) :: buf
    write(buf, '(I2 2/ I2)') 1, 2   ! {error C1302 repeated-slash}
end subroutine
subroutine c1302_format_stmt()
    implicit none
    character(40) :: buf
    write(buf, 10) 1, 2
10  format(I2I2)   ! {error C1302 format-stmt}
end subroutine

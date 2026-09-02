! C1302 (R1303): same violation as C1302_bad_1, but the format is a variable,
! so the violation can only be detected at run time.
program c1302_bad_4
    implicit none
    character(40) :: buf
    character(6) :: fmt = '(I2I2)'
    write(buf, fmt) 1, 2   ! {error C1302}
end program

! C1302 (R1303): comma omitted between two I edit descriptors, which is not
! one of the permitted omissions.
program c1302_bad_1
    implicit none
    character(40) :: buf
    write(buf, '(I2I2)') 1, 2   ! {error C1302}
end program

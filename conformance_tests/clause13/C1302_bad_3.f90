! C1302 (R1303): comma omitted before a slash that HAS a repeat count.
program c1302_bad_3
    implicit none
    character(40) :: buf
    write(buf, '(I2 2/ I2)') 1, 2   ! {error C1302}
end program

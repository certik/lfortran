! C1302 (R1303): comma omitted between a P edit descriptor and an I edit
! descriptor; only F, E, EN, ES, EX, D and G may follow P without a comma.
program c1302_bad_2
    implicit none
    character(40) :: buf
    write(buf, '(1PI4)') 1   ! {error C1302}
end program

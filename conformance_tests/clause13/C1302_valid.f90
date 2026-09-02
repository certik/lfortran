! C1302 (R1303): the comma between format items may be omitted only
!   - between P and an immediately following F/E/EN/ES/EX/D/G edit descriptor,
!   - before a slash without repeat count, after a slash,
!   - before or after a colon.
! Valid: each permitted omission.
program c1302_valid
    implicit none
    character(10) :: buf(2)
    write(buf(1), '(1PE10.3)') 1.5     ! P then E, no comma
    if (buf(1) /= " 1.500E+00") error stop
    write(buf, '(I2/I2)') 1, 2         ! comma omitted before and after /
    if (buf(1)(1:2) /= " 1" .or. buf(2)(1:2) /= " 2") error stop
    write(buf(1), '(I2:I2)') 3         ! comma omitted around :
    if (buf(1)(1:2) /= " 3") error stop
end program

! C1121 (R1124) The do-variable shall be a variable of type integer.
! (The syntax is fine per R1123; the violation is semantic.)
program c1121_bad_1
    implicit none
    real :: x
    do x = 1.0, 3.0   ! {error C1121}
    end do
end program

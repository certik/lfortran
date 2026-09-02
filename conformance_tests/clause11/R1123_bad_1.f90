! R1123: loop-control requires both a lower and an upper bound expression;
! `do i = 1` has only one.
program r1123_bad_1
    implicit none
    integer :: i
    do i = 1   ! {error R1123}
    end do
end program

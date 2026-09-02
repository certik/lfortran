! R1123: a loop-control has at most three scalar-int-exprs (start, end, step).
program r1123_bad_3
    implicit none
    integer :: i
    do i = 1, 10, 2, 3   ! {error R1123}
    end do
end program

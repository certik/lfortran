! R1123: the WHILE alternative requires a parenthesised scalar-logical-expr.
program r1123_bad_2
    implicit none
    integer :: n
    n = 0
    do while n < 3   ! {error R1123}
        n = n + 1
    end do
end program

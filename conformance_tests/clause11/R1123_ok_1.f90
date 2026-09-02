! R1123 loop-control is [ , ] do-variable = scalar-int-expr, scalar-int-expr [ , scalar-int-expr ]
!                     or [ , ] WHILE ( scalar-logical-expr )
!                     or [ , ] CONCURRENT concurrent-header concurrent-locality
! Valid: every alternative, with and without the optional leading comma.
program r1123_ok_1
    implicit none
    integer :: i, n, a(3), b(3)
    n = 0
    do i = 1, 3
        n = n + 1
    end do
    do, i = 1, 3
        n = n + 1
    end do
    do i = 1, 6, 2
        n = n + 1
    end do
    do while (n < 12)
        n = n + 1
    end do
    do, while (n < 15)
        n = n + 1
    end do
    a = 0
    do concurrent (i = 1:3)
        a(i) = i
    end do
    do, concurrent (i = 1:3)
        b(i) = 2 * i
    end do
    if (n /= 15) error stop
    if (sum(a) /= 6 .or. sum(b) /= 12) error stop
end program

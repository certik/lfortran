! R1123 loop-control is [ , ] do-variable = scalar-int-expr, scalar-int-expr [ , scalar-int-expr ]
!                     or [ , ] WHILE ( scalar-logical-expr )
!                     or [ , ] CONCURRENT concurrent-header concurrent-locality
! Valid: every alternative, with and without the optional leading comma, with
! and without the optional step, and with a concurrent-locality.
! Note: gfortran 13 rejects the locality specs (LOCAL, LOCAL_INIT, SHARED,
! DEFAULT(NONE)); flang 18 accepts them.
program r1123_valid
    implicit none
    integer :: i, n, t, u, a(3), b(3), c(3)
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
    do i = 3, 1, -1
        n = n + 1
    end do
    do while (n < 15)
        n = n + 1
    end do
    do, while (n < 18)
        n = n + 1
    end do
    if (n /= 18) error stop
    a = 0
    do concurrent (i = 1:3)
        a(i) = i
    end do
    do, concurrent (i = 1:3)
        b(i) = 2 * i
    end do
    if (sum(a) /= 6 .or. sum(b) /= 12) error stop
    u = 100
    do concurrent (i = 1:3) local(t) local_init(u) shared(c) default(none)
        t = 2 * i
        u = u + i
        c(i) = t + u
    end do
    if (u /= 100) error stop
    if (sum(c) /= 12 + 306) error stop
end program

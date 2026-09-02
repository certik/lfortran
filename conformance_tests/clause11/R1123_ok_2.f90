! R1123 loop-control, CONCURRENT alternative with a concurrent-locality
! (LOCAL, LOCAL_INIT, SHARED, DEFAULT(NONE)).  Split from R1123_ok_1 because
! gfortran 13 does not support locality specs.
program r1123_ok_2
    implicit none
    integer :: i, t, u, b(3)
    u = 100
    do concurrent (i = 1:3) local(t) local_init(u) shared(b) default(none)
        t = 2 * i
        u = u + i
        b(i) = t + u
    end do
    if (u /= 100) error stop
    if (sum(b) /= 12 + 306) error stop
end program

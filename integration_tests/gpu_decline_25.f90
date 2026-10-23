! gpu decline reason: LiveoutScalar
! A scalar the loop defines that EQUIVALENCE makes another name read after
! the loop, which the buffer that carries a value back to the host cannot
! hold: the name the loop defines it through is a pointer.
program gpu_decline_25
    implicit none
    integer :: s, t, a(100), i
    equivalence (s, t)
    s = 0
    do concurrent (i = 1:100)
        if (i == 3) s = 7
        a(i) = i
    end do
    print *, t
    if (t /= 7) error stop 1
end program

! A scalar a `do concurrent` defines in one iteration keeps that value
! (Fortran 2018, 11.1.7.5) when a procedure the program contains reads it
! after the loop, when a GO TO runs the statements before the loop again,
! when it is a TARGET a pointer reads, and when a procedure defines it
! only in the iteration that passes it a 3; one every iteration defines
! and then reads, which a contained procedure only names for a variable of
! its own, is a temporary of the iteration.
module gpu_liveout_04_m
    implicit none
contains
    pure subroutine maybe(s, i)
        integer, intent(inout) :: s
        integer, intent(in) :: i
        if (i == 3) s = 7
    end subroutine
end module

program gpu_liveout_04
    use gpu_liveout_04_m
    implicit none
    integer, target :: tg
    integer, pointer :: q
    integer :: k, m, s, t, i, it
    integer :: a(100)
    k = 0
    do concurrent (i = 1:100)
        a(i) = i
        if (i == 7) k = 7
    end do
    call show()
    q => tg
    tg = 0
    do concurrent (i = 1:100)
        if (i == 3) tg = 7
        a(i) = i
    end do
    if (q /= 7) error stop 3
    s = 0
    do concurrent (i = 1:100)
        call maybe(s, i)
        a(i) = i
    end do
    if (s /= 7) error stop 4
    do concurrent (i = 1:100)
        t = 2 * i
        a(i) = t - i
    end do
    do i = 1, 100
        if (a(i) /= i) error stop 5
    end do
    m = 0
    it = 0
10  continue
    if (it == 1) then
        print *, m
        if (m /= 9) error stop 2
        stop
    end if
    do concurrent (i = 1:100)
        a(i) = 2 * i
        if (i == 9) m = 9
    end do
    it = it + 1
    goto 10
contains
    subroutine show()
        integer :: t
        t = 1
        print *, k, t
        if (k /= 7) error stop 1
    end subroutine
end program

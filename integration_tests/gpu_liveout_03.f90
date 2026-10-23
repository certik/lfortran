! A pointer or allocatable scalar a `do concurrent` defines in one
! iteration keeps that value after the loop (Fortran 2018, 11.1.7.5).
module gpu_liveout_03_m
    implicit none
contains
    subroutine s(n, p, a)
        integer, intent(in) :: n
        integer, pointer, intent(inout) :: p
        integer, allocatable, intent(inout) :: a
        integer :: i
        do concurrent (i = 1:n)
            if (i == 2) p = 10 * i
            if (i == 3) a = 7
        end do
    end subroutine
end module

program gpu_liveout_03
    use gpu_liveout_03_m
    implicit none
    integer, target :: t
    integer, pointer :: p
    integer, allocatable :: a
    real, allocatable :: r
    integer :: i
    t = 0
    p => t
    allocate(a)
    a = 0
    call s(5, p, a)
    print *, t, a
    if (t /= 20) error stop 1
    if (a /= 7) error stop 2
    allocate(r)
    r = 1.5
    do concurrent (i = 1:4)
        if (i == 4) r = 2.5 * i
    end do
    print *, r
    if (r /= 10.0) error stop 3
end program

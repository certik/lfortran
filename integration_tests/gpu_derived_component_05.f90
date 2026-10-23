! A derived-type variable with an allocatable component that every
! iteration of a `do concurrent` passes whole to a procedure that defines
! it, and then reads, is a temporary of the iteration (Fortran 2018,
! 11.1.7.5): each iteration reads what its own call defined.
module gpu_derived_component_05_m
    implicit none
    type :: u
        real, allocatable :: w(:)
        integer :: k
    end type
contains
    pure subroutine set(p, i)
        type(u), intent(inout) :: p
        integer, intent(in) :: i
        p%k = i
    end subroutine

    subroutine s(p, a)
        type(u), intent(inout) :: p
        integer, intent(out) :: a(:)
        integer :: i
        do concurrent (i = 1:size(a))
            call set(p, i)
            a(i) = p%k
            p%k = 0
        end do
    end subroutine
end module

program gpu_derived_component_05
    use gpu_derived_component_05_m
    implicit none
    integer, parameter :: n = 100000
    type(u) :: p
    integer, allocatable :: a(:)
    integer :: i
    allocate(a(n))
    p%k = 5
    call s(p, a)
    do i = 1, n
        if (a(i) /= i) error stop 1
    end do
    print *, a(1), a(n)
end program

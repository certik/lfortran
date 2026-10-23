! The parts of a derived-type variable a `do concurrent` defines: an
! element of an array component, allocatable or not, is defined in place,
! as an element of an array is, whatever the size of the array; a scalar
! component of a component that every iteration defines and then reads is
! a temporary of the iteration (Fortran 2018, 11.1.7.5), and what one
! iteration alone defines of it, directly or through a procedure that may
! leave it unchanged in the others, is kept.
module gpu_derived_component_07_m
    implicit none
    type :: grid
        real, allocatable :: f(:)
        real :: coef(3)
        integer :: n
    end type
    type :: inner_t
        integer :: k
    end type
    type :: u
        real, allocatable :: w(:)
        type(inner_t) :: inner
        real :: c(100)
    end type
    type :: big
        real :: c(200000)
        integer :: k
    end type
    type :: pair
        integer :: a, b
    end type
contains
    subroutine init(g)
        type(grid), intent(inout) :: g
        integer :: i
        do concurrent (i = 1:3)
            g%coef(i) = 0.5 * i
        end do
        do concurrent (i = 1:g%n)
            g%f(i) = i
        end do
    end subroutine

    pure subroutine bump(y, i)
        type(pair), intent(inout) :: y
        integer, intent(in) :: i
        if (i == 3) y%a = 7
        if (i == 5) y%b = 9
    end subroutine
end module

program gpu_derived_component_07
    use gpu_derived_component_07_m
    implicit none
    integer, parameter :: n = 100000
    type(grid) :: g
    type(u) :: y
    type(big), save :: z
    type(pair) :: p
    integer, allocatable :: a(:)
    integer :: i
    allocate(a(n))
    g%n = 10
    allocate(g%f(10))
    call init(g)
    if (g%coef(2) /= 1.0 .or. g%f(10) /= 10) error stop 1
    allocate(y%w(100))
    y%w = 0
    y%c = 0
    y%inner%k = 0
    do concurrent (i = 1:100)
        y%c(i) = 2 * i
        y%w(i) = 3 * i
        if (i == 3) y%inner%k = 7
    end do
    if (y%c(7) /= 14 .or. y%w(7) /= 21) error stop 2
    if (y%inner%k /= 7) error stop 3
    do concurrent (i = 1:n)
        y%inner%k = 2 * i
        a(i) = y%inner%k - i
    end do
    do i = 1, n
        if (a(i) /= i) error stop 4
    end do
    z%c = 0
    do concurrent (i = 1:200000)
        z%c(i) = 2 * i
    end do
    if (z%c(7) /= 14) error stop 5
    p = pair(0, 0)
    do concurrent (i = 1:n)
        call bump(p, i)
        a(i) = i
    end do
    if (p%a /= 7 .or. p%b /= 9) error stop 6
    y%inner%k = 0
    print *, g%coef(2), y%c(7), a(n), z%c(7), p%a, p%b
end program

! The predefined empty trait AnyType and unconstrained generic parameters of
! procedures: `{AnyType :: T}` means the same as an unconstrained `{T}`, and
! needs no USE. An unconstrained parameter admits any type, intrinsic or
! derived, inferred from the data arguments or given explicitly, and mixes
! with constrained parameters. The names AnyType and Trait are not reserved:
! a variable may take them.
module traits_anytype_01_m
    implicit none
    private
    public :: INum, Pair, Box, id, any_id, swap, scaled_copy, first_of, copy_into

    abstract interface :: INum
        integer | real
    end interface INum

    type :: Pair
        integer :: a = 0
        real :: b = 0
    end type Pair

    type :: Box
        integer :: tag = 0
    contains
        procedure :: keep => box_keep
    end type Box

contains

    function id{U}(x) result(r)
        type(U), intent(in) :: x
        type(U) :: r
        r = x
    end function id

    function any_id{AnyType :: T}(x) result(r)
        type(T), intent(in) :: x
        type(T) :: r
        type(T) :: tmp
        tmp = x
        r = tmp
    end function any_id

    subroutine swap{U}(x, y)
        type(U), intent(inout) :: x, y
        type(U) :: t
        t = x
        x = y
        y = t
    end subroutine swap

    ! A constrained parameter has its operations; an unconstrained one is
    ! only copied.
    subroutine scaled_copy{INum :: T, U}(x, y, sx, sy)
        type(T), intent(in) :: x
        type(U), intent(in) :: y
        type(T), intent(out) :: sx
        type(U), intent(out) :: sy
        sx = x + x
        sy = y
    end subroutine scaled_copy

    ! AnyType is the identity of a trait combination.
    function first_of{AnyType + INum :: T, AnyType :: U}(x, y) result(r)
        type(T), intent(in) :: x
        type(U), intent(in) :: y
        type(T) :: r
        type(U) :: unused
        unused = y
        r = x * x
    end function first_of

    subroutine copy_into{U}(x, n, y)
        type(U), intent(in) :: x
        integer, intent(in) :: n
        type(U), intent(out) :: y(n)
        integer :: i
        do i = 1, n
            y(i) = id(x)
        end do
    end subroutine copy_into

    function box_keep{U}(self, x) result(r)
        class(Box), intent(in) :: self
        type(U), intent(in) :: x
        type(U) :: r
        if (self%tag < 0) error stop "negative tag"
        r = x
    end function box_keep

end module traits_anytype_01_m

program traits_anytype_01
    use traits_anytype_01_m
    implicit none
    integer :: anytype = 5
    integer :: trait = 1
    integer :: i, j, k
    real :: r, s
    type(Pair) :: p, q, ps(3)
    type(Box) :: b

    ! Inferred from intrinsic and derived data arguments.
    if (id(3) /= 3) error stop 1
    if (id(2.5) /= 2.5) error stop 2
    p = Pair(7, 1.5)
    q = id(p)
    if (q%a /= 7 .or. q%b /= 1.5) error stop 3
    if (any_id(anytype) /= 5) error stop 4
    q = any_id(Pair(4, 0.25))
    if (q%a /= 4 .or. q%b /= 0.25) error stop 5
    if (.not. any_id(.true.)) error stop 6

    ! Explicit type arguments.
    if (id{integer}(11) /= 11) error stop 7
    if (any_id{real}(0.5) /= 0.5) error stop 8
    q = id{Pair}(p)
    if (q%a /= 7) error stop 9

    ! A generic subroutine with an unconstrained parameter.
    i = 1
    j = 2
    call swap(i, j)
    if (i /= 2 .or. j /= 1) error stop 10
    p = Pair(1, 1.0)
    q = Pair(2, 2.0)
    call swap(p, q)
    if (p%a /= 2 .or. q%a /= 1) error stop 11
    r = 1.0
    s = 3.0
    call swap{real}(r, s)
    if (r /= 3.0 .or. s /= 1.0) error stop 12

    ! Mixed constrained and unconstrained parameters.
    call scaled_copy(3, Pair(9, 9.0), k, q)
    if (k /= 6 .or. q%a /= 9) error stop 13
    call scaled_copy(1.5, 4, r, j)
    if (r /= 3.0 .or. j /= 4) error stop 14
    call scaled_copy{integer, Pair}(5, p, k, q)
    if (k /= 10 .or. q%a /= 2) error stop 15
    if (first_of(4, p) /= 16) error stop 16
    if (first_of(1.5, .false.) /= 2.25) error stop 17

    ! Passing an unconstrained parameter on to another generic.
    call copy_into(Pair(3, 3.0), 3, ps)
    if (any(ps%a /= 3)) error stop 18

    ! A generic binding with an unconstrained parameter.
    b%tag = 1
    if (b%keep(8) /= 8) error stop 19
    q = b%keep(Pair(6, 6.0))
    if (q%a /= 6) error stop 20

    ! The predefined names remain ordinary names elsewhere.
    if (anytype /= 5 .or. trait /= 1) error stop 21
    anytype = anytype + trait
    if (anytype /= 6) error stop 22
    print '(a)', 'traits_anytype_01 ok'
end program traits_anytype_01

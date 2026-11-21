! Partially explicit type arguments (DI extension E5): the leading type
! arguments of a generic procedure are given and the call infers the rest,
! for free generic functions and subroutines and for type-bound generic
! procedures, with trait parameters first. Inside a generic, a call can mix
! binders of the enclosing generic, forwarded, with concrete type arguments,
! explicit or inferred: the call is instantiated with each instance of the
! enclosing generic. A conformance constraint `P :: U` with P forwarded and
! U concrete is checked there.
! GFortran does not accept this LFortran extension.
module traits_partial_type_args_01_m
    implicit none
    private
    public :: IShow, INum, A, B, Box, pair, wrap, scored, as_show, make, &
        make_twice, names_twice, through_box, put_free, nested

    abstract interface :: IShow
        integer function code(self)
            type(itself), intent(in), pass :: self
        end function code
    end interface IShow

    abstract interface :: INum
        integer | real
    end interface INum

    type, implements(IShow) :: A
        integer :: v = 1
    contains
        procedure :: code => a_code
    end type A

    type, implements(IShow) :: B
        integer :: w = 5
    contains
        procedure :: code => b_code
    end type B

    type, sealed :: Box
        integer :: k = 100
    contains
        procedure :: combine
        procedure :: put
    end type Box

contains

    integer function a_code(self)
        class(A), intent(in) :: self
        a_code = self%v
    end function a_code

    integer function b_code(self)
        class(B), intent(in) :: self
        b_code = self%w * 10
    end function b_code

    ! The second argument's value, doubled.
    function pair{INum :: T, INum :: U}(x, y) result(r)
        type(T), intent(in) :: x
        type(U), intent(in) :: y
        type(U) :: r
        r = y + y
        if (x /= x) r = y
    end function pair

    function wrap{Trait :: P, P :: U}(x) result(r)
        type(U), intent(in) :: x
        class(P), allocatable :: r
        r = x
    end function wrap

    function described{Trait :: P, P :: U}(x) result(r)
        type(U), intent(in) :: x
        character(:), allocatable :: r
        r = type_name{P}() // "/" // type_name{U}()
    end function described

    ! A concrete type with requirements and a forwarded binder, inferred.
    function score{IShow :: T, INum :: K}(x, m) result(r)
        type(T), intent(in) :: x
        type(K), intent(in) :: m
        type(K) :: r
        r = m + m
        if (x%code() /= 4) r = m
    end function score

    function scored{INum :: K}(m) result(r)
        type(K), intent(in) :: m
        type(K) :: r
        r = score(A(4), m)
    end function scored

    ! A concrete trait and a forwarded type, whose constraint implies it.
    function as_show{IShow :: T}(x) result(r)
        type(T), intent(in) :: x
        integer :: r
        class(IShow), allocatable :: v
        v = wrap{IShow}(x)
        r = v%code()
    end function as_show

    ! A forwarded trait and a concrete type.
    function make{Trait :: P}(n) result(r)
        integer, intent(in) :: n
        class(P), allocatable :: r
        r = wrap{P}(A(n))
    end function make

    ! Pure forwarding of a generic that mixes.
    function make_twice{Trait :: P}(n) result(r)
        integer, intent(in) :: n
        class(P), allocatable :: r
        r = make{P}(n + 1)
    end function make_twice

    function names{Trait :: P}() result(r)
        character(:), allocatable :: r
        r = described{P}(B())
    end function names

    function names_twice{Trait :: Q}() result(r)
        character(:), allocatable :: r
        r = names{Q}() // "+" // described{Q}(A())
    end function names_twice

    subroutine put{Trait :: P, P :: U}(self, x, n)
        type(Box), intent(in) :: self
        type(U), intent(in) :: x
        integer, intent(out) :: n
        class(P), allocatable :: v
        v = x
        n = self%k
        if (.not. allocated(v)) n = 0
    end subroutine put

    function combine{INum :: T, INum :: U}(self, x, y) result(r)
        type(Box), intent(in) :: self
        type(T), intent(in) :: x
        type(U), intent(in) :: y
        type(T) :: r
        r = x + x
        if (y /= y) r = x
    end function combine

    subroutine put_free{Trait :: P, P :: U}(x, n)
        type(U), intent(in) :: x
        integer, intent(out) :: n
        class(P), allocatable :: v
        v = x
        n = 1
        if (.not. allocated(v)) n = 0
    end subroutine put_free

    ! Type-bound and subroutine calls that mix.
    function through_box{Trait :: P, INum :: T}(bx, x) result(r)
        type(Box), intent(in) :: bx
        type(T), intent(in) :: x
        type(T) :: r
        integer :: n, m
        call bx%put{P}(A(7), n)
        if (n /= 100) error stop 20
        call put_free{P}(B(), m)
        if (m /= 1) error stop 21
        r = bx%combine{T, integer}(x, n)
    end function through_box

    ! Explicit and inferred concrete arguments after a forwarded one.
    function nested{INum :: T}(x) result(r)
        type(T), intent(in) :: x
        real :: r
        r = pair{T, real}(x, 1.25) + pair(x, 2.5) + real(pair{T}(x, 3))
    end function nested

end module traits_partial_type_args_01_m

program traits_partial_type_args_01
    use traits_partial_type_args_01_m
    implicit none
    class(IShow), allocatable :: v
    type(Box) :: bx
    integer :: n

    ! Leading explicit type arguments, the rest inferred.
    if (pair{integer}(1, 2.5) /= 5.0) error stop 1
    if (pair{real}(1.5, 2) /= 4) error stop 2
    if (bx%combine{integer}(3, 2.5) /= 6) error stop 3
    call put_free{IShow}(A(9), n)
    if (n /= 1) error stop 4
    call bx%put{IShow}(B(), n)
    if (n /= 100) error stop 5
    v = wrap{IShow}(B())
    if (v%code() /= 50) error stop 6

    ! Mixed forwarded and concrete type arguments.
    if (scored(3) /= 6) error stop 7
    if (scored(1.5) /= 3.0) error stop 8
    if (as_show(B()) /= 50) error stop 9
    v = make{IShow}(3)
    if (v%code() /= 3) error stop 10
    v = make_twice{IShow}(3)
    if (v%code() /= 4) error stop 11
    if (names_twice{IShow}() /= "IShow/B+IShow/A") error stop 12
    if (through_box{IShow}(bx, 2.5) /= 5.0) error stop 13
    if (through_box{IShow}(bx, 4) /= 8) error stop 14
    if (nested(1) /= 13.5) error stop 15
    if (nested(0.5) /= 13.5) error stop 16
    print *, "PASSED"
end program traits_partial_type_args_01

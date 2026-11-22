! The bindings of a type's implements blocks and its generic binding of the
! same name are one generic (DI extension E6). A reference selects a
! non-generic specific by the standard rules, also by the rank of an
! argument, in preference to a generic one; it reaches an implements-block
! binding through any receiver, also a component or an array element; and
! nested references of the name are resolved once each. A character scalar
! is sequence associated with an explicit-shape or assumed-size character
! dummy of an implements-block binding, as in an ordinary reference.
! GFortran does not accept this LFortran extension.
module traits_generic_overload_05_m
    implicit none
    private
    public :: IShow, A, B, C, D, E, F, Wrap

    abstract interface :: IShow
        integer function tag(self)
            type(itself), intent(in), pass :: self
        end function tag
    end interface IShow

    implements IShow :: integer
        procedure :: tag => int_tag
    end implements

    implements IShow :: real
        procedure :: tag => real_tag
    end implements

    abstract interface :: IA
        integer function serve(self, x)
            type(itself), intent(in), pass :: self
            integer, intent(in) :: x
        end function serve
    end interface IA

    abstract interface :: IB
        integer function serve{IShow :: T}(self, x)
            type(itself), intent(in), pass :: self
            type(T), intent(in) :: x
        end function serve
    end interface IB

    abstract interface :: IC
        integer function serve(self, x)
            type(itself), intent(in), pass :: self
            integer, intent(in) :: x(:)
        end function serve
    end interface IC

    abstract interface :: ID
        integer function serve(self)
            type(itself), intent(in), pass :: self
        end function serve
    end interface ID

    abstract interface :: IE
        integer function serve(self, x)
            type(itself), intent(in), pass :: self
            real, intent(in) :: x
        end function serve
    end interface IE

    abstract interface :: IF
        integer function serve(self, x)
            type(itself), intent(in), pass :: self
            character, intent(in) :: x(4)
        end function serve
        integer function take(self, x)
            type(itself), intent(in), pass :: self
            character, intent(in) :: x(*)
        end function take
    end interface IF

    ! A non-generic implements-block binding and a generic specific.
    type :: A
        integer :: id = 3
    contains
        generic   :: serve => serve_t
        procedure :: serve_t
    end type A

    ! A generic implements-block binding and a non-generic specific.
    type :: B
        integer :: id = 3
    contains
        generic   :: serve => b_serve_n
        procedure :: b_serve_n
    end type B

    ! Non-generic, distinguished by the rank of an argument.
    type :: C
        integer :: id = 3
    contains
        generic   :: serve => c_serve_n
        procedure :: c_serve_n
    end type C

    ! Non-generic, distinguished by the number of arguments.
    type :: D
        integer :: id = 3
    contains
        generic   :: serve => d_serve_n
        procedure :: d_serve_n
    end type D

    type :: Wrap
        type(D) :: d
        type(D) :: ds(2)
    end type Wrap

    ! Non-generic, distinguished by type; nested references.
    type :: E
    contains
        generic   :: serve => e_serve_n
        procedure :: e_serve_n
    end type E

    ! Character sequence association.
    type :: F
        integer :: id = 3
    end type F

    implements IA :: A
        procedure :: serve => a_other
    end implements

    implements IB :: B
        procedure :: serve => b_other
    end implements

    implements IC :: C
        procedure :: serve => c_other
    end implements

    implements ID :: D
        procedure :: serve => d_other
    end implements

    implements IE :: E
        procedure :: serve => e_other
    end implements

    implements IF :: F
        procedure :: serve => f_other
        procedure :: take => f_take
    end implements

contains

    integer function int_tag(self)
        integer, intent(in) :: self
        int_tag = 2
    end function int_tag

    integer function real_tag(self)
        real, intent(in) :: self
        real_tag = 1
    end function real_tag

    integer function a_other(self, x)
        class(A), intent(in) :: self
        integer, intent(in) :: x
        a_other = 40 + x
    end function a_other

    integer function serve_t{T}(self, x)
        class(A), intent(in) :: self
        type(T), intent(in) :: x
        serve_t = 7
    end function serve_t

    integer function b_other{IShow :: T}(self, x)
        class(B), intent(in) :: self
        type(T), intent(in) :: x
        b_other = 40 + x%tag()
    end function b_other

    integer function b_serve_n(self, n)
        class(B), intent(in) :: self
        integer, intent(in) :: n
        b_serve_n = self%id * n
    end function b_serve_n

    integer function c_other(self, x)
        class(C), intent(in) :: self
        integer, intent(in) :: x(:)
        c_other = 40 + size(x)
    end function c_other

    integer function c_serve_n(self, n)
        class(C), intent(in) :: self
        integer, intent(in) :: n
        c_serve_n = self%id * n
    end function c_serve_n

    integer function d_other(self)
        class(D), intent(in) :: self
        d_other = 42
    end function d_other

    integer function d_serve_n(self, n)
        class(D), intent(in) :: self
        integer, intent(in) :: n
        d_serve_n = self%id * n
    end function d_serve_n

    integer function e_other(self, x)
        class(E), intent(in) :: self
        real, intent(in) :: x
        e_other = 42
    end function e_other

    integer function e_serve_n(self, n)
        class(E), intent(in) :: self
        integer, intent(in) :: n
        e_serve_n = n + 1
    end function e_serve_n

    integer function f_other(self, x)
        class(F), intent(in) :: self
        character, intent(in) :: x(4)
        f_other = ichar(x(2)) + self%id
    end function f_other

    integer function f_take(self, x)
        class(F), intent(in) :: self
        character, intent(in) :: x(*)
        f_take = ichar(x(3))
    end function f_take

end module traits_generic_overload_05_m

program traits_generic_overload_05
    use traits_generic_overload_05_m
    implicit none
    type(A) :: va
    type(B) :: vb
    type(C) :: vc
    type(D) :: arr(2)
    type(E) :: ve
    type(F) :: vf
    character(len=4) :: s
    type(Wrap) :: w
    integer :: k

    ! The non-generic specific is selected, wherever it is bound.
    if (va%serve(2) /= 42) error stop 1
    if (va%serve(2.5) /= 7) error stop 2
    if (vb%serve(2) /= 6) error stop 3
    if (vb%serve(2.5) /= 41) error stop 4

    if (vc%serve(2) /= 6) error stop 5
    if (vc%serve([1, 2]) /= 42) error stop 6

    if (w%d%serve() /= 42) error stop 7
    if (arr(1)%serve() /= 42) error stop 8
    if (w%ds(1)%serve() /= 42) error stop 9
    if (w%d%serve(2) /= 6) error stop 10
    if (arr(2)%serve(3) /= 9) error stop 11
    if (w%ds(2)%serve(4) /= 12) error stop 12

    k = ve%serve(ve%serve(ve%serve(ve%serve(ve%serve(ve%serve(ve%serve( &
        ve%serve(ve%serve(ve%serve(ve%serve(ve%serve(ve%serve(ve%serve( &
        ve%serve(ve%serve(0))))))))))))))))
    if (k /= 16) error stop 13
    if (ve%serve(1.0) /= 42) error stop 14

    s = 'abcd'
    if (vf%serve(s) /= ichar('b') + 3) error stop 15
    if (vf%take(s) /= ichar('c')) error stop 16
    if (vf%serve('wxyz') /= ichar('x') + 3) error stop 17
    print *, va%serve(2), vb%serve(2), vc%serve([1, 2]), w%d%serve(), k
end program traits_generic_overload_05

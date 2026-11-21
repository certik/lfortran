! Conformance constraints between generic parameters (E2): in
! `{Trait :: P, P :: U}` the type bound to U must implement the trait bound
! to P, which is checked where the generic is instantiated. In the generic,
! U has no operations, but a value of type(U) converts to class(P), by
! assignment or as an actual argument. P is explicit and U inferred, or both
! are explicit; both are passed on to other generics.
! GFortran does not accept this LFortran extension.
module traits_trait_param_02_m
    implicit none
    private
    public :: IShow, INamed, A, B, Registry, wrap, wrap_by_call, wrap_twice, keep

    abstract interface :: IShow
        integer function code(self)
            type(itself), intent(in), pass :: self
        end function code
    end interface IShow

    abstract interface :: INamed
        integer function name_length(self)
            type(itself), intent(in), pass :: self
        end function name_length
    end interface INamed

    type, implements(IShow) :: A
        integer :: v = 7
    contains
        procedure :: code => a_code
    end type A

    type, implements(IShow + INamed) :: B
        integer :: w = 1
    contains
        procedure :: code => b_code
        procedure :: name_length => b_name_length
    end type B

    type, sealed :: Registry
        integer :: count = 0
    contains
        procedure :: register
    end type Registry

contains

    integer function a_code(self)
        class(A), intent(in) :: self
        a_code = self%v
    end function a_code

    integer function b_code(self)
        class(B), intent(in) :: self
        b_code = 100 * self%w
    end function b_code

    integer function b_name_length(self)
        class(B), intent(in) :: self
        b_name_length = 1 + self%w
    end function b_name_length

    ! A value of type(U) assigned to class(P).
    function wrap{Trait :: P, P :: U}(x) result(r)
        type(U), intent(in) :: x
        class(P), allocatable :: r
        type(U) :: copy
        copy = x
        r = copy
    end function wrap

    ! A value of type(U) passed to a class(P) dummy.
    function wrap_by_call{Trait :: P, P :: U}(x) result(r)
        type(U), intent(in) :: x
        class(P), allocatable :: r
        r = keep{P}(x)
    end function wrap_by_call

    function keep{Trait :: Q}(view) result(copy)
        class(Q), intent(in) :: view
        class(Q), allocatable :: copy
        copy = view
    end function keep

    ! P and U passed on, U inferred there.
    function wrap_twice{Trait :: P, P :: U}(x) result(r)
        type(U), intent(in) :: x
        class(P), allocatable :: r
        r = wrap{P}(x)
    end function wrap_twice

    subroutine register{Trait :: P, P :: U}(self, x)
        type(Registry), intent(inout) :: self
        type(U), intent(in) :: x
        class(P), allocatable :: stored
        stored = wrap{P, U}(x)
        if (allocated(stored)) self%count = self%count + 1
    end subroutine register

end module traits_trait_param_02_m

program traits_trait_param_02
    use traits_trait_param_02_m
    implicit none
    type(Registry) :: reg
    class(IShow), allocatable :: s
    class(INamed), allocatable :: n
    type(B) :: b2

    s = wrap{IShow}(A(3))
    if (s%code() /= 3) error stop 1
    s = wrap{IShow, B}(B(2))
    if (s%code() /= 200) error stop 2
    b2 = B(4)
    n = wrap{INamed}(b2)
    if (n%name_length() /= 5) error stop 3

    s = wrap_by_call{IShow}(A(9))
    if (s%code() /= 9) error stop 4
    n = wrap_by_call{INamed}(B(6))
    if (n%name_length() /= 7) error stop 5

    s = wrap_twice{IShow}(B(3))
    if (s%code() /= 300) error stop 6

    call reg%register{IShow}(A(1))
    call reg%register{INamed}(B(1))
    call reg%register{IShow}(B(1))
    if (reg%count /= 3) error stop 7
    print '(a)', 'traits_trait_param_02 ok'
end program traits_trait_param_02

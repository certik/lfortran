! AnyType on generic derived types: `Holder{AnyType :: U}` is the unconstrained
! `Holder{U}`, an implements header may spell the parameter either way, and a
! method of a generic type may take its own unconstrained parameter.
module traits_anytype_02_m
    implicit none
    private
    public :: Holder, Pair

    type :: Pair
        integer :: a = 0
    end type Pair

    type, sealed :: Holder{AnyType :: U}
        type(U) :: item
    end type Holder

    implements :: Holder{U}
        initial   :: init
        procedure :: get
        procedure :: put
        procedure :: other
    end implements

contains

    function init(x) result(self)
        type(U), intent(in) :: x
        type(Holder{U}) :: self
        self%item = x
    end function init

    function get(self) result(r)
        type(Holder{U}), intent(in) :: self
        type(U) :: r
        r = self%item
    end function get

    subroutine put(self, x)
        type(Holder{U}), intent(inout) :: self
        type(U), intent(in) :: x
        self%item = x
    end subroutine put

    function other{V}(self, y) result(r)
        type(Holder{U}), intent(in) :: self
        type(V), intent(in) :: y
        type(V) :: r
        type(U) :: tmp
        tmp = self%item
        r = y
    end function other

end module traits_anytype_02_m

program traits_anytype_02
    use traits_anytype_02_m
    implicit none
    type(Pair) :: p
    hi := Holder{integer}(4)
    hp := Holder{Pair}(Pair(3))
    if (hi%get() /= 4) error stop 1
    call hi%put(9)
    if (hi%get() /= 9) error stop 2
    p = hp%get()
    if (p%a /= 3) error stop 3
    call hp%put(Pair(8))
    p = hp%get()
    if (p%a /= 8) error stop 4
    if (hi%other(2.5) /= 2.5) error stop 5
    p = hi%other(Pair(5))
    if (p%a /= 5) error stop 6
    print '(a)', 'traits_anytype_02 ok'
end program traits_anytype_02

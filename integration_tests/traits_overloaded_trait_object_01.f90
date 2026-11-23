! The MRE of https://github.com/lfortran/lfortran/issues/18552: both
! overloads of IContainer%register, called through class(IContainer).
! GFortran does not accept this LFortran extension.
module traits_overloaded_trait_object_01_m
    implicit none
    private
    public :: IValue, IContainer, ISetup, Cell, Container, Setup, make_cell, make_from

    abstract interface
        function ctor0{U}() result(res)
            type(U) :: res
        end function ctor0
        function ctor1{Trait :: T1, U}(a) result(res)
            class(T1), intent(in) :: a
            type(U) :: res
        end function ctor1
    end interface

    abstract interface :: IValue
        integer function value(self)
            type(itself), pass, intent(in) :: self
        end function value
    end interface IValue

    abstract interface :: IContainer
        subroutine register{Trait :: P, P :: U}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor0{U}) :: ctor
        end subroutine register
        subroutine register{Trait :: P, Trait :: T1, P :: U}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor1{T1, U}) :: ctor
        end subroutine register
    end interface IContainer

    abstract interface :: ISetup
        subroutine registration(self, c)
            type(itself), pass, intent(in) :: self
            class(IContainer), intent(inout) :: c
        end subroutine registration
    end interface ISetup

    type, implements(IValue) :: Cell
        integer :: n = 0
    contains
        procedure :: value => cell_value
    end type Cell

    type, sealed, implements(IContainer) :: Container
        integer :: n0 = 0, n1 = 0
    contains
        generic :: register => register0, register1
        procedure :: register0, register1
    end type Container

    type, implements(ISetup) :: Setup
    contains
        procedure :: registration => setup_registration
    end type Setup

contains

    integer function cell_value(self)
        class(Cell), intent(in) :: self
        cell_value = self%n
    end function cell_value

    function make_cell() result(res)
        type(Cell) :: res
        res%n = 1
    end function make_cell

    function make_from(a) result(res)
        class(IValue), intent(in) :: a
        type(Cell) :: res
        res%n = a%value() + 10
    end function make_from

    subroutine register0{Trait :: P, P :: U}(self, ctor)
        type(Container), intent(inout) :: self
        procedure(ctor0{U}) :: ctor
        self%n0 = self%n0 + 1
    end subroutine register0

    subroutine register1{Trait :: P, Trait :: T1, P :: U}(self, ctor)
        type(Container), intent(inout) :: self
        procedure(ctor1{T1, U}) :: ctor
        self%n1 = self%n1 + 1
    end subroutine register1

    subroutine setup_registration(self, c)
        class(Setup), intent(in) :: self
        class(IContainer), intent(inout) :: c
        call c%register{IValue}(make_cell)
        call c%register{IValue}(make_from)
    end subroutine setup_registration

end module traits_overloaded_trait_object_01_m

program traits_overloaded_trait_object_01
    use traits_overloaded_trait_object_01_m
    implicit none
    type(Container) :: cont
    type(Setup) :: s
    type(Cell) :: seed, res

    call cont%register{IValue}(make_cell)
    call cont%register{IValue}(make_from)
    call s%registration(cont)
    if (cont%n0 /= 2 .or. cont%n1 /= 2) error stop 1
    seed%n = 3
    res = make_from(seed)
    if (res%n /= 13) error stop 2
end program traits_overloaded_trait_object_01

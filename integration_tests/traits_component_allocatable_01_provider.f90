! A derived type with an allocatable trait-object component and a client module
! that allocates an extension of an abstract type. Both are compiled separately
! so that the allocation's structural type is read back from a module file.
module traits_component_allocatable_01_m
    implicit none

    abstract interface :: IValue
        integer function value(self)
            type(itself), intent(in), pass :: self
        end function value
    end interface IValue

    type, abstract :: AbsType
    end type AbsType

    type, extends(AbsType) :: MyType
        class(IValue), allocatable :: obj
    end type MyType

    type, implements(IValue) :: Counter
        integer :: n = 42
    contains
        procedure :: value => counter_value
    end type Counter

contains

    integer function counter_value(self)
        class(Counter), intent(in) :: self
        counter_value = self%n
    end function counter_value

end module traits_component_allocatable_01_m

module traits_component_allocatable_01_client_m
    use traits_component_allocatable_01_m
    implicit none

    type :: Client
    contains
        procedure :: method
        procedure :: run
    end type Client

contains

    subroutine method(self, arr)
        class(Client), intent(in) :: self
        class(AbsType), allocatable, intent(out) :: arr(:)
        allocate(MyType :: arr(1))
    end subroutine method

    subroutine run(self)
        class(Client), intent(in) :: self
        class(AbsType), allocatable :: arr(:)

        call self%method(arr)
        if (size(arr) /= 1) error stop 1
        select type (arr)
        type is (MyType)
            allocate(Counter :: arr(1)%obj)
            if (arr(1)%obj%value() /= 42) error stop 2
        class default
            error stop 3
        end select
    end subroutine run

end module traits_component_allocatable_01_client_m

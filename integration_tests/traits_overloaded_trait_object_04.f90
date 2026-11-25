! Regression test for https://github.com/lfortran/lfortran/issues/18647:
! a DI container implementing IContainer whose register0{Trait::P, P::U}
! wraps the constructor in Factory(ctor) -> Factory0{U}(ctor) boxed into
! class(IFactory), registered through a class(IContainer) trait object and
! resolved and invoked at runtime.
! GFortran does not accept this LFortran extension.
module traits_overloaded_trait_object_04_interfaces
    implicit none

    abstract interface :: IResolver
        function resolve{Trait :: P}(self) result(res)
            type(itself), pass, intent(in) :: self
            class(P), allocatable :: res
        end function resolve
    end interface

    abstract interface :: IFactory
        function create(self, c) result(res)
            type(itself), pass, intent(in) :: self
            class(IResolver), intent(in) :: c
            class(*), allocatable :: res
        end function create
    end interface

    abstract interface
        function ctor0{U}() result(res)
            type(U) :: res
        end function ctor0
    end interface

    abstract interface, extends(IResolver) :: IContainer
        subroutine register{Trait :: P, P :: U}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor0{U}) :: ctor
        end subroutine register
    end interface

    abstract interface :: ISetup
        subroutine registration(self, c)
            type(itself), pass, intent(in) :: self
            class(IContainer), intent(inout) :: c
        end subroutine registration
    end interface

    abstract interface :: IValue
        integer function value(self)
            type(itself), pass, intent(in) :: self
        end function value
    end interface
end module traits_overloaded_trait_object_04_interfaces

module traits_overloaded_trait_object_04_factory
    use traits_overloaded_trait_object_04_interfaces
    implicit none

    type, sealed, implements(IFactory) :: Factory
        private
        class(IFactory), allocatable :: box
    contains
        initial :: init0
        procedure :: create
    end type Factory

    type, sealed, implements(IFactory) :: Factory0{U}
        private
        procedure(ctor0{U}), pointer, nopass :: ctor => null()
    contains
        procedure :: create => create0
    end type Factory0
contains
    function init0{U}(ctor) result(self)
        procedure(ctor0{U}) :: ctor
        type(Factory) :: self
        self%box = Factory0(ctor)
    end function init0

    function create(self, c) result(res)
        type(Factory), intent(in) :: self
        class(IResolver), intent(in) :: c
        class(*), allocatable :: res
        res = self%box%create(c)
    end function create

    function create0(self, c) result(res)
        type(Factory0{U}), intent(in) :: self
        class(IResolver), intent(in) :: c
        class(*), allocatable :: res
        res = self%ctor()
    end function create0
end module traits_overloaded_trait_object_04_factory

module traits_overloaded_trait_object_04_container
    use traits_overloaded_trait_object_04_interfaces
    use traits_overloaded_trait_object_04_factory
    implicit none

    type, sealed, implements(IContainer) :: Container
        character(:), allocatable :: saved_key
        class(IFactory), allocatable :: saved_factory
    contains
        initial :: init
        procedure :: register0
        generic :: register => register0
        procedure :: resolve
    end type Container
contains
    function init() result(self)
        type(Container) :: self
    end function init

    subroutine register0{Trait :: P, P :: U}(self, ctor)
        type(Container), intent(inout) :: self
        procedure(ctor0{U}) :: ctor
        self%saved_key = type_name{P}(qualified=.true.)
        self%saved_factory = Factory(ctor)
    end subroutine register0

    function resolve{Trait :: P}(self) result(res)
        type(Container), intent(in) :: self
        class(P), allocatable :: res
        if (.not. allocated(self%saved_factory)) error stop 10
        if (self%saved_key /= type_name{P}(qualified=.true.)) error stop 11
        select type (obj => self%saved_factory%create(self))
        class is (P)
            res = obj
        class default
            error stop 12
        end select
    end function resolve
end module traits_overloaded_trait_object_04_container

module traits_overloaded_trait_object_04_setup
    use traits_overloaded_trait_object_04_interfaces
    implicit none

    type, implements(IValue) :: Answer
        integer :: n = 42
    contains
        procedure :: value => answer_value
    end type Answer

    type, sealed, implements(ISetup) :: Setup
    contains
        procedure :: registration
    end type Setup
contains
    integer function answer_value(self)
        class(Answer), intent(in) :: self
        answer_value = self%n
    end function answer_value

    subroutine registration(self, c)
        type(Setup), intent(in) :: self
        class(IContainer), intent(inout) :: c
        call c%register{IValue}(Answer)
    end subroutine registration
end module traits_overloaded_trait_object_04_setup

program traits_overloaded_trait_object_04
    use traits_overloaded_trait_object_04_interfaces
    use traits_overloaded_trait_object_04_container
    use traits_overloaded_trait_object_04_setup
    implicit none

    class(IContainer), allocatable :: c
    class(ISetup), allocatable :: s
    class(IValue), allocatable :: v

    c = Container()
    s = Setup()
    call s%registration(c)
    v = c%resolve{IValue}()
    if (v%value() /= 42) error stop 1
end program traits_overloaded_trait_object_04

! Regression test for https://github.com/lfortran/lfortran/issues/18617:
! calling an overloaded generic message through a trait object when a trait
! parameter (T1 = ISomeTrait) is inferred from a type's initializer in another
! module. The runtime contract for ISomeTrait must be imported into the
! caller's scope when constructing the TraitDescriptor argument.
! GFortran does not accept this LFortran extension.
module traits_overloaded_trait_object_03_interfaces
    implicit none
    abstract interface
        function ctor0{U}() result(res)
            type(U) :: res
        end function ctor0
        function ctor1{Trait :: T1, U}(a) result(res)
            class(T1), intent(in) :: a
            type(U) :: res
        end function ctor1
    end interface

    abstract interface :: IContainer
        subroutine register{Trait :: P, P :: U}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor0{U}) :: ctor
        end subroutine register
        subroutine register{Trait :: P, Trait :: T1, P :: U}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor1{T1, U}) :: ctor
        end subroutine register
    end interface
end module traits_overloaded_trait_object_03_interfaces

module traits_overloaded_trait_object_03_mytype
    implicit none
    abstract interface :: ISomeTrait
    end interface

    abstract interface :: IMyType
    end interface

    type, implements(IMyType) :: MyType
    contains
        initial :: init
    end type MyType
contains
    function init(obj) result(self)
        class(ISomeTrait), intent(in) :: obj
        type(MyType) :: self
    end function init
end module traits_overloaded_trait_object_03_mytype

module traits_overloaded_trait_object_03_client
    use traits_overloaded_trait_object_03_interfaces
    use traits_overloaded_trait_object_03_mytype
    implicit none

    type, sealed :: Client
    contains
        procedure :: registration
    end type Client

    type, sealed, implements(IContainer) :: Container
        integer :: n0 = 0, n1 = 0
    contains
        generic :: register => register0, register1
        procedure :: register0, register1
    end type Container
contains
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

    subroutine registration(self, c)
        type(Client), intent(in) :: self
        class(IContainer), intent(inout) :: c
        call c%register{IMyType}(MyType)
    end subroutine registration
end module traits_overloaded_trait_object_03_client

program traits_overloaded_trait_object_03
    use traits_overloaded_trait_object_03_client
    implicit none
    type(Client) :: cli
    type(Container) :: cont

    call cli%registration(cont)
    if (cont%n0 /= 0 .or. cont%n1 /= 1) error stop 1
end program traits_overloaded_trait_object_03

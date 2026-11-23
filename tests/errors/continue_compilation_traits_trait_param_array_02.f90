! A generic message called through trait objects (E10) passes its trait
! parameter on to a generic that declares a generic type with an array of
! class(P) as a component, which is not implemented yet. A separate file:
! the failed binding stops the checks of the other erased copies.
module continue_compilation_traits_trait_param_array_02_m0
    implicit none
    abstract interface :: IShow
        integer function code(self)
            type(itself), intent(in), pass :: self
        end function code
    end interface IShow

    type, implements(IShow) :: A
        integer :: v = 1
    contains
        procedure :: code => a_code
    end type A

contains

    integer function a_code(self)
        class(A), intent(in) :: self
        a_code = self%v
    end function a_code
end module continue_compilation_traits_trait_param_array_02_m0

module continue_compilation_traits_trait_param_array_02_m1
    use continue_compilation_traits_trait_param_array_02_m0, only: A
    implicit none

    abstract interface :: ILookup
        function lookup{Trait :: P}(self) result(res)
            type(itself), intent(in), pass :: self
            class(P), allocatable :: res
        end function lookup
    end interface ILookup

    type :: Vec{Trait :: P}
        class(P), allocatable :: items(:)
    end type Vec

    type, sealed, implements(ILookup) :: Nested
        integer :: n = 0
    contains
        procedure :: lookup => nested_lookup
    end type Nested

contains

    function first_item{Trait :: P}(x) result(r)
        class(P), intent(in) :: x
        class(P), allocatable :: r
        type(Vec{P}) :: v
        allocate(v%items(1), source=x)
        r = v%items(1)
    end function first_item

    function nested_lookup{Trait :: P}(self) result(res)
        type(Nested), intent(in) :: self
        class(P), allocatable :: res
        class(*), allocatable :: obj
        obj = A(3)
        select type (obj)
        class is (P)
            res = first_item{P}(obj)
        end select
    end function nested_lookup
end module continue_compilation_traits_trait_param_array_02_m1

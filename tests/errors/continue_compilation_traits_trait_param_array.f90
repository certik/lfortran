! Arrays of trait objects of a trait parameter `{Trait :: P}` (#18485):
! the trait bound to P is not known in the generic, so a class(P) array is
! allocated only with a class(P) source and takes only class(P) arrays; its
! elements are defined only in definable arrays; and a generic message
! called through trait objects cannot declare one yet (E10).
module continue_compilation_traits_trait_param_array_m0
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

    integer function count_items{Trait :: P}(arr) result(n)
        class(P), intent(in) :: arr(:)
        n = size(arr)
    end function count_items

    subroutine typed{Trait :: P}(arr)
        class(P), allocatable, intent(inout) :: arr(:)
        allocate(A :: arr(2))
    end subroutine typed

    subroutine concrete_source{Trait :: P}(arr)
        class(P), allocatable, intent(inout) :: arr(:)
        allocate(arr(2), source=A(3))
    end subroutine concrete_source

    subroutine molded{Trait :: P}(arr, b)
        class(P), allocatable, intent(inout) :: arr(:)
        class(P), intent(in) :: b(:)
        allocate(arr(2), mold=b)
    end subroutine molded

    integer function concrete_actual{Trait :: P}() result(n)
        type(A) :: xs(2)
        n = count_items{P}(xs)
    end function concrete_actual

    integer function other_trait{Trait :: P}(arr) result(n)
        class(IShow), intent(in) :: arr(:)
        n = count_items{P}(arr)
    end function other_trait

    subroutine define_in{Trait :: P}(arr, x)
        class(P), intent(in) :: arr(:)
        class(P), intent(in) :: x
        arr(1) = x
    end subroutine define_in

    subroutine define_concrete(arr)
        class(IShow), intent(in) :: arr(:)
        arr(1) = A(2)
    end subroutine define_concrete
end module continue_compilation_traits_trait_param_array_m0

! The erased copy of `resolve`, which a runtime view of Container needs.
module continue_compilation_traits_trait_param_array_m1
    implicit none

    abstract interface :: IResolver
        function resolve{Trait :: P}(self) result(res)
            type(itself), intent(in), pass :: self
            class(P), allocatable :: res
        end function resolve
    end interface IResolver

    type, sealed, implements(IResolver) :: Container
        integer :: n = 0
    contains
        procedure :: resolve => container_resolve
    end type Container

contains

    function container_resolve{Trait :: P}(self) result(res)
        type(Container), intent(in) :: self
        class(P), allocatable :: res
        class(P), allocatable :: cache(:)
        if (allocated(cache)) res = cache(1)
    end function container_resolve
end module continue_compilation_traits_trait_param_array_m1

! The erased copy of `resolve` passes P on to a generic with such an array.
module continue_compilation_traits_trait_param_array_m2
    implicit none

    abstract interface :: IFinder
        function find{Trait :: P}(self) result(res)
            type(itself), intent(in), pass :: self
            class(P), allocatable :: res
        end function find
    end interface IFinder

    type, sealed, implements(IFinder) :: Finder
        integer :: n = 0
    contains
        procedure :: find => finder_find
    end type Finder

contains

    function cached{Trait :: P}(x) result(r)
        class(P), intent(in) :: x
        class(P), allocatable :: r
        class(P), allocatable :: items(:)
        allocate(items(2), source=x)
        r = items(2)
    end function cached

    function finder_find{Trait :: P}(self) result(res)
        type(Finder), intent(in) :: self
        class(P), allocatable :: res
        class(*), allocatable :: obj
        obj = self
        select type (obj)
        class is (P)
            res = cached{P}(obj)
        end select
    end function finder_find
end module continue_compilation_traits_trait_param_array_m2

! A class(P) array is not an array of a named trait; an array SOURCE and
! section assignment are not implemented yet; assigning to an element of a
! definable trait array is an LFortran extension (a warning).
module continue_compilation_traits_trait_param_array_m3
    use continue_compilation_traits_trait_param_array_m0, only: IShow, A
    implicit none
contains

    integer function show_all(arr) result(n)
        class(IShow), intent(in) :: arr(:)
        n = size(arr)
    end function show_all

    integer function named_dummy{Trait :: P}(arr) result(n)
        class(P), intent(in) :: arr(:)
        n = show_all(arr)
    end function named_dummy

    subroutine array_source{Trait :: P}(arr, b)
        class(P), allocatable, intent(inout) :: arr(:)
        class(P), intent(in) :: b(:)
        allocate(arr(2), source=b)
    end subroutine array_source

    subroutine define_section{Trait :: P}(arr, x)
        class(P), intent(inout) :: arr(:)
        class(P), intent(in) :: x
        arr(1:2) = x
    end subroutine define_section

    subroutine define_element{Trait :: P}(arr, x)
        class(P), intent(inout) :: arr(:)
        class(P), intent(in) :: x
        arr(1) = x
    end subroutine define_element

    subroutine define_named_element(arr)
        class(IShow), intent(inout) :: arr(:)
        arr(2) = A(5)
    end subroutine define_named_element

    subroutine polymorphic_source(arr, b)
        class(IShow), allocatable, intent(inout) :: arr(:)
        class(A), intent(in) :: b
        allocate(arr(2), source=b)
    end subroutine polymorphic_source

    subroutine intrinsic_source(arr)
        class(IShow), allocatable, intent(inout) :: arr(:)
        allocate(arr(2), source=1)
    end subroutine intrinsic_source
end module continue_compilation_traits_trait_param_array_m3

! The erased copy of `lookup` declares a generic type with an array of
! class(P) as a component.
module continue_compilation_traits_trait_param_array_m4
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

    type, sealed, implements(ILookup) :: Direct
        integer :: n = 0
    contains
        procedure :: lookup => direct_lookup
    end type Direct

contains

    function direct_lookup{Trait :: P}(self) result(res)
        type(Direct), intent(in) :: self
        class(P), allocatable :: res
        type(Vec{P}) :: v
        if (allocated(v%items)) res = v%items(1)
    end function direct_lookup
end module continue_compilation_traits_trait_param_array_m4

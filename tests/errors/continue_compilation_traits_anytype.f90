! The predefined names AnyType and Trait cannot name a derived type or a
! trait, and an unconstrained generic parameter has no operations.
module continue_compilation_traits_anytype_m1
    implicit none
    type :: AnyType
        integer :: v
    end type AnyType
end module continue_compilation_traits_anytype_m1

module continue_compilation_traits_anytype_m2
    implicit none
    type :: trait
        integer :: v
    end type trait
end module continue_compilation_traits_anytype_m2

module continue_compilation_traits_anytype_m3
    implicit none
    abstract interface :: AnyType
        integer function get(self)
            type(itself), pass, intent(in) :: self
        end function get
    end interface AnyType
end module continue_compilation_traits_anytype_m3

module continue_compilation_traits_anytype_m4
    implicit none
    abstract interface :: Trait
    end interface Trait
end module continue_compilation_traits_anytype_m4

module continue_compilation_traits_anytype_m5
    implicit none
    type :: AnyType{U}
        type(U) :: item
    end type AnyType
end module continue_compilation_traits_anytype_m5

module continue_compilation_traits_anytype_m6
    implicit none
contains
    function twice{U}(x) result(r)
        type(U), intent(in) :: x
        type(U) :: r
        r = x + x
    end function twice
end module continue_compilation_traits_anytype_m6

module continue_compilation_traits_anytype_m7
    implicit none
contains
    function twice{AnyType :: T}(x) result(r)
        type(T), intent(in) :: x
        type(T) :: r
        r = x * x
    end function twice
end module continue_compilation_traits_anytype_m7

module continue_compilation_traits_anytype_m8
    implicit none
contains
    function pick{AnyType(Element = integer) :: T}(x) result(r)
        type(T), intent(in) :: x
        type(T) :: r
        r = x
    end function pick
end module continue_compilation_traits_anytype_m8

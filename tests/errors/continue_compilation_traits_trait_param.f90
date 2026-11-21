! Trait parameters `{Trait :: P}` (E1) and conformance constraints
! `{P :: U}` (E2): a trait is not a type, the arguments of trait and type
! parameters are checked, and the type bound to U must implement the trait
! bound to P.
module continue_compilation_traits_trait_param_m0
    implicit none
    abstract interface :: IShow
        integer function code(self)
            type(itself), intent(in), pass :: self
        end function code
    end interface IShow

    abstract interface :: IOther
        subroutine other(self)
            type(itself), intent(in), pass :: self
        end subroutine other
    end interface IOther

    abstract interface :: IResolver
        function resolve{Trait :: P}(self) result(res)
            type(itself), intent(in), pass :: self
            class(P), allocatable :: res
        end function resolve
    end interface IResolver

    type, implements(IShow) :: A
        integer :: v = 1
    contains
        procedure :: code => a_code
    end type A

    type :: Printer
        integer :: w = 2
    end type Printer

contains

    integer function a_code(self)
        class(A), intent(in) :: self
        a_code = self%v
    end function a_code

    subroutine none{Trait :: P}()
    end subroutine none

    integer function first{IShow :: T}(x) result(r)
        type(T), intent(in) :: x
        r = x%code()
    end function first

    subroutine register0{Trait :: P, P :: U}(x)
        type(U), intent(in) :: x
    end subroutine register0
end module continue_compilation_traits_trait_param_m0

module continue_compilation_traits_trait_param_m1
    implicit none
contains
    ! A trait is not a type.
    subroutine s{Trait :: P}()
        type(P) :: x
    end subroutine s
end module continue_compilation_traits_trait_param_m1

module continue_compilation_traits_trait_param_m2
    use continue_compilation_traits_trait_param_m0
    implicit none
contains
    ! A type argument for a trait parameter.
    subroutine type_for_trait()
        call none{A}()
    end subroutine type_for_trait
end module continue_compilation_traits_trait_param_m2

module continue_compilation_traits_trait_param_m3
    use continue_compilation_traits_trait_param_m0
    implicit none
contains
    ! A trait argument for a type parameter.
    subroutine trait_for_type()
        integer :: n
        n = first{IShow}(A())
    end subroutine trait_for_type
end module continue_compilation_traits_trait_param_m3

module continue_compilation_traits_trait_param_m4
    use continue_compilation_traits_trait_param_m0
    implicit none
contains
    ! The type bound to U does not implement the trait bound to P.
    subroutine not_conforming()
        call register0{IShow}(Printer())
    end subroutine not_conforming
end module continue_compilation_traits_trait_param_m4

module continue_compilation_traits_trait_param_m5
    use continue_compilation_traits_trait_param_m0
    implicit none
contains
    ! Only an earlier trait parameter can constrain another parameter.
    subroutine later{U :: V, Trait :: U}()
    end subroutine later
end module continue_compilation_traits_trait_param_m5

module continue_compilation_traits_trait_param_m6
    use continue_compilation_traits_trait_param_m0
    implicit none
contains
    ! The trait bound to P is not known in the generic.
    function make{Trait :: P}() result(r)
        class(P), allocatable :: r
        r = A()
    end function make
end module continue_compilation_traits_trait_param_m6

module continue_compilation_traits_trait_param_m7
    use continue_compilation_traits_trait_param_m0
    implicit none
contains
    ! A trait object of a trait parameter has no messages in the generic.
    integer function use_view{Trait :: P}(view) result(r)
        class(P), intent(in) :: view
        r = view%code()
    end function use_view
end module continue_compilation_traits_trait_param_m7

module continue_compilation_traits_trait_param_m8
    use continue_compilation_traits_trait_param_m0
    implicit none
contains
    ! The meta-trait cannot be combined with traits.
    subroutine combined{Trait + IShow :: P}()
    end subroutine combined
end module continue_compilation_traits_trait_param_m8

module continue_compilation_traits_trait_param_m9
    use continue_compilation_traits_trait_param_m0
    implicit none
contains
    ! A trait parameter is not a type in a TYPE IS guard.
    logical function exact{Trait :: P}(object) result(ok)
        class(*), intent(in) :: object
        ok = .false.
        select type (x => object)
        type is (P)
            ok = .true.
        end select
    end function exact
end module continue_compilation_traits_trait_param_m9

module continue_compilation_traits_trait_param_m10
    use continue_compilation_traits_trait_param_m0
    implicit none
contains
    ! The precedence of a trait parameter's guard among trait guards.
    integer function which{Trait :: P}(object) result(r)
        class(*), intent(in) :: object
        r = 0
        select type (x => object)
        class is (P)
            r = 1
        class is (IOther)
            r = 2
        end select
    end function which
end module continue_compilation_traits_trait_param_m10

module continue_compilation_traits_trait_param_m11
    use continue_compilation_traits_trait_param_m0
    implicit none
    ! A generic message with trait parameters is called through trait objects
    ! (E10) only with a class(P), allocatable or scalar result and scalar
    ! numeric or logical other arguments, not with a class(P) argument.
    abstract interface :: IAccept
        logical function accept{Trait :: P}(self, x)
            type(itself), intent(in), pass :: self
            class(P), intent(in) :: x
        end function accept
    end interface IAccept
contains
    subroutine through_object()
        class(IResolver), allocatable :: c
        class(IAccept), allocatable :: a
    end subroutine through_object
end module continue_compilation_traits_trait_param_m11

module continue_compilation_traits_trait_param_m12
    implicit none
    ! Conformance constraints of generic derived types.
    type :: Holder{Trait :: P, P :: U}
        integer :: n = 0
    end type Holder
end module continue_compilation_traits_trait_param_m12

module continue_compilation_traits_trait_param_m13
    use continue_compilation_traits_trait_param_m0
    implicit none
contains
    ! Trait combinations as arguments of trait parameters.
    subroutine combination()
        call none{IShow + IOther}()
    end subroutine combination
end module continue_compilation_traits_trait_param_m13

module continue_compilation_traits_trait_param_m14
    implicit none
    abstract interface :: IPair
        integer function pair{Trait :: P, Trait :: Q}(self)
            type(itself), intent(in), pass :: self
        end function pair
    end interface IPair
contains
    ! A forwarded and a concrete trait argument through a trait object (E10).
    integer function mixed{Trait :: T1}(c) result(r)
        class(IPair), intent(in) :: c
        r = c%pair{T1, IPair}()
    end function mixed
end module continue_compilation_traits_trait_param_m14

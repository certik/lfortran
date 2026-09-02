! C726 (R721 R722 R723) A type-param-value of * shall be used only
!   - to declare a dummy argument, - to declare a named constant,
!   - in the type-spec of an ALLOCATE statement wherein each allocate-object is a
!     dummy argument of type CHARACTER with an assumed character length,
!   - in the type-spec or derived-type-spec of a type guard statement, or
!   - in an external function, to declare the character length parameter of the
!     function result.
! Each case is its own program unit so that cases cannot interfere.
module c726_component
    implicit none
    type :: t
        character(*) :: s   ! {error C726 component}
    end type
end module
module c726_module_function_result
    implicit none
contains
    function f() result(r)
        character(*) :: r   ! {error C726 module-function-result}
        r = "abc"
    end function
end module
subroutine c726_local_variable()
    implicit none
    character(*) :: s   ! {error C726 local-variable}
    s = "abc"
end subroutine
subroutine c726_allocate_local()
    implicit none
    character(:), allocatable :: s
    allocate(character(*) :: s)   ! {error C726 allocate-local}
end subroutine
subroutine c726_allocate_dummy_not_assumed(d)
    implicit none
    character(:), allocatable, intent(out) :: d
    allocate(character(*) :: d)   ! {error C726 allocate-dummy-deferred}
end subroutine
subroutine c726_internal_function_result()
    implicit none
    print *, g()
contains
    function g() result(r)
        character(*) :: r   ! {error C726 internal-function-result}
        r = "x"
    end function
end subroutine

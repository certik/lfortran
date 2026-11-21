! The type_name intrinsic (E7) takes exactly one type argument, which names
! a type or a trait, and an optional logical constant `qualified`.
module continue_compilation_traits_type_name_m
    implicit none
    abstract interface :: IShow
        integer function code(self)
            type(itself), intent(in), pass :: self
        end function code
    end interface IShow

    type :: A
        integer :: v = 1
    end type A
end module continue_compilation_traits_type_name_m

program continue_compilation_traits_type_name
    use continue_compilation_traits_type_name_m
    implicit none
    integer :: x
    logical :: flag
    flag = .true.
    ! No type argument.
    print *, type_name()
    ! Two type arguments.
    print *, type_name{A, IShow}()
    ! A variable is not a type.
    print *, type_name{x}()
    ! qualified must be a logical constant expression.
    print *, type_name{A}(qualified=flag)
    print *, type_name{A}(qualified=1)
    ! qualified is the only argument.
    print *, type_name{A}(kind=1)
    print *, type_name{A}(.true., .false.)
end program continue_compilation_traits_type_name

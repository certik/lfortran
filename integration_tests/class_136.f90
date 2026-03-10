module class_136_mod
    implicit none

    type, abstract :: base_type
    contains
        procedure, non_overridable :: copy
        generic :: assignment(=) => copy
        procedure(copy_iface), deferred :: copy_impl
    end type

    abstract interface
        subroutine copy_iface(lhs, rhs)
            import base_type
            class(base_type), intent(inout) :: lhs
            class(base_type), intent(in) :: rhs
        end subroutine
    end interface

    type, extends(base_type) :: vec
        class(*), allocatable :: v(:)
    contains
        procedure :: copy_impl => vec_copy
    end type

contains

    recursive subroutine copy(lhs, rhs)
        class(base_type), intent(inout) :: lhs
        class(base_type), intent(in) :: rhs
        call lhs%copy_impl(rhs)
    end subroutine

    subroutine vec_copy(lhs, rhs)
        class(vec), intent(inout) :: lhs
        class(base_type), intent(in) :: rhs
        select type (rhs)
        type is (vec)
            lhs%v = rhs%v
        end select
    end subroutine

end module

program class_136
    use class_136_mod
    implicit none
    type(vec) :: x, y

    x%v = [1, 2]
    y = x
    x%v = [3.14]

    select type (v => y%v)
    type is (integer)
        if (any(v /= [1, 2])) error stop
    class default
        error stop
    end select
    print *, "PASS"
end program

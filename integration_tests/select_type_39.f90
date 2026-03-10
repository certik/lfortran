program select_type_39
! Test that same-named derived types in different subroutine scopes
! are correctly distinguished in select type with class(*) arrays.
implicit none
call sub1()
call sub2()
contains
    subroutine sub1()
        type point
            real :: x, y
        end type
        class(*), allocatable :: val(:)
        allocate(val, source=[point(1.0, 2.0)])
        select type (val)
        type is (point)
            if (val(1)%x /= 1.0) error stop
            if (val(1)%y /= 2.0) error stop
        class default
            error stop
        end select
    end subroutine

    subroutine sub2()
        type point
            real :: x, y
        end type
        class(*), allocatable :: val(:)
        allocate(val, source=[point(3.0, 4.0)])
        select type (val)
        type is (point)
            if (val(1)%x /= 3.0) error stop
            if (val(1)%y /= 4.0) error stop
        class default
            error stop
        end select
    end subroutine
end program

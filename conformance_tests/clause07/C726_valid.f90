! C726 (R721 R722 R723) A type-param-value of * shall be used only
!   - to declare a dummy argument,
!   - to declare a named constant,
!   - in the type-spec of an ALLOCATE statement wherein each allocate-object is a
!     dummy argument of type CHARACTER with an assumed character length,
!   - in the type-spec or derived-type-spec of a type guard statement, or
!   - in an external function, to declare the character length parameter of the
!     function result.
! Valid: every permitted use of `*` as a type-param-value.
module c726_valid_m
    implicit none
    type :: pt(n)
        integer, len :: n
        character(n) :: s
    end type
contains
    subroutine s1(a, b, c)
        character(*), intent(in) :: a            ! dummy argument
        character(len=*), intent(in) :: b        ! dummy argument, keyword form
        type(pt(*)), intent(in) :: c             ! dummy argument, derived-type length param
        if (len(a) /= 3) error stop
        if (len(b) /= 2) error stop
        if (c%n /= 4) error stop
    end subroutine
    subroutine s2(x)
        class(*), intent(in) :: x
        select type (x)
        type is (character(*))                    ! type guard statement
            if (len(x) /= 5) error stop
        class default
            error stop
        end select
    end subroutine
end module
program c726_valid
    use c726_valid_m
    implicit none
    character(*), parameter :: k = "named"       ! named constant
    type(pt(4)) :: v
    v%s = "abcd"
    call s1("abc", "de", v)
    call s2(k)
end program

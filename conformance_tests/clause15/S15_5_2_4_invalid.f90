! S15.5.2.4 (not a numbered rule): "The dummy argument shall be type
! compatible with the actual argument ... the actual argument shall have the
! same kind type parameters" (15.5.2.4 para 2, normative text).  Mixed-kind
! argument mistakes are the most common kind-related error in practice, so
! they are tested even though the standard does not number this requirement.
! Each case uses an explicit interface (internal procedure or module).
module s15524_m
    implicit none
contains
    subroutine t(x)
        real(8), intent(in) :: x
    end subroutine
end module
subroutine s15524_real4_to_real8()
    implicit none
    real(4) :: a = 1.0
    call s(a)   ! {error S15.5.2.4 real4-to-real8}
contains
    subroutine s(x)
        real(8), intent(in) :: x
    end subroutine
end subroutine
subroutine s15524_real8_to_real4()
    implicit none
    real(8) :: a = 1.0d0
    call s(a)   ! {error S15.5.2.4 real8-to-real4}
contains
    subroutine s(x)
        real(4), intent(in) :: x
    end subroutine
end subroutine
subroutine s15524_int4_to_int8()
    implicit none
    integer(4) :: n = 1
    call s(n)   ! {error S15.5.2.4 int4-to-int8}
contains
    subroutine s(x)
        integer(8), intent(in) :: x
    end subroutine
end subroutine
subroutine s15524_literal_real4_to_real8()
    implicit none
    call s(1.0)   ! {error S15.5.2.4 literal-real4-to-real8}
contains
    subroutine s(x)
        real(8), intent(in) :: x
    end subroutine
end subroutine
subroutine s15524_logical1_to_logical4()
    implicit none
    logical(1) :: l = .true._1
    call s(l)   ! {error S15.5.2.4 logical1-to-logical4}
contains
    subroutine s(x)
        logical(4), intent(in) :: x
    end subroutine
end subroutine
subroutine s15524_char4_to_char1()
    implicit none
    character(kind=4, len=1) :: c = 4_"a"
    call s(c)   ! {error S15.5.2.4 char4-to-char1}
contains
    subroutine s(x)
        character(kind=1, len=1), intent(in) :: x
    end subroutine
end subroutine
subroutine s15524_function_result_kind()
    implicit none
    real(8) :: y
    y = f(1.0)   ! {error S15.5.2.4 function-arg-real4-to-real8}
contains
    real(8) function f(x)
        real(8), intent(in) :: x
        f = x
    end function
end subroutine
subroutine s15524_module_procedure()
    use s15524_m
    implicit none
    call t(1.0)   ! {error S15.5.2.4 module-procedure-real4-to-real8}
end subroutine

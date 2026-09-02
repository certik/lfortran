! C722 (R714) The value of kind-param shall specify an approximation method
! that exists on the processor.
! Kind 7 is used as the nonexistent kind: no known compiler has real kind 7
! (flang has 2 and 3, gfortran and flang have 10; 7 is free everywhere).
subroutine c722_digit_string()
    implicit none
    real :: r
    r = 1.0_7   ! {error C722 digit-string}
end subroutine
subroutine c722_named_constant()
    implicit none
    integer, parameter :: k = 7
    real :: r
    r = 1.0_k   ! {error C722 named-constant}
end subroutine
subroutine c722_exponent_form()
    implicit none
    real :: r
    r = 1.0e0_7   ! {error C722 exponent-form}
end subroutine
subroutine c722_in_constant_expression()
    implicit none
    real, parameter :: p = 2.0_7 * 3.0   ! {error C722 constant-expression}
end subroutine
subroutine c722_in_array_constructor()
    implicit none
    real :: a(2)
    a = [1.0_7, 2.0_7]   ! {error C722 array-constructor}
end subroutine

! C722 (R714) The value of kind-param shall specify an approximation method
! that exists on the processor.
! Valid: real literals with every way of writing an existing kind-param:
! digit-string, named constant, kind inquiry, and an optional kind chosen
! portably with the ISO_FORTRAN_ENV constants (no preprocessor needed).
program c722_valid
    use iso_fortran_env, only: real32, real64, real128
    implicit none
    integer, parameter :: sp = real32, dp = real64
    integer, parameter :: qp = merge(real128, real64, real128 > 0)
    real(sp) :: a
    real(dp) :: b
    real(qp) :: c
    a = 1.5_4
    b = 1.5_8
    a = 1.5_sp
    b = 1.5e0_dp
    b = 1.5d0                       ! no kind-param: D exponent selects double
    c = 1.5_qp
    a = 1.5_real32
    b = 2.5_real64
    if (kind(1.5_4) /= 4 .or. kind(1.5_8) /= 8) error stop
    if (kind(1.5_sp) /= sp .or. kind(1.5e0_dp) /= dp) error stop
    if (kind(1.5d0) /= dp) error stop
    if (kind(1.5_qp) /= qp) error stop
    if (a /= 1.5_sp .or. b /= 2.5_dp .or. c /= 1.5_qp) error stop
end program

! Two files that both use the same intrinsics must link: the procedures the
! compiler builds to implement them must not clash between the object files.
program multi_file_intrinsic_01
    implicit none
    interface
        subroutine multi_file_intrinsic_01_ext(x, n, r, s, k, m, p, j)
            integer, intent(in) :: n
            real, intent(in) :: x(n)
            real, intent(out) :: r, s(n)
            integer, intent(out) :: k, m, p, j
        end subroutine multi_file_intrinsic_01_ext
        function multi_file_intrinsic_01_diag_a(a) result(res)
            real, intent(in) :: a(:,:)
            real :: res(maxval(shape(a)))
        end function multi_file_intrinsic_01_diag_a
        function multi_file_intrinsic_01_diag_b(a) result(res)
            real, intent(in) :: a(:,:)
            real :: res(minval(shape(a)))
        end function multi_file_intrinsic_01_diag_b
    end interface
    real :: x(3), r, s(3), a(2, 3), d(3), e(2)
    integer :: ia(3), k, m, p, j
    x = [1.0, 2.0, 3.0]
    ia = [7, 5, 6]
    call multi_file_intrinsic_01_ext(x, 3, r, s, k, m, p, j)
    print *, r, s, k, m, p, j
    if (abs(r - (sum(x) + sin(x(1)) + maxval(x) + product(x))) > 1e-5) error stop
    if (any(abs(s - sin(x)) > 1e-5)) error stop
    if (k /= iall(ia)) error stop
    if (k /= 4) error stop
    if (m /= merge(1, 2, any(x > 2.0)) + count(x > 1.5)) error stop
    if (m /= 3) error stop
    if (p /= modulo(ia(1), 4) + exponent(x(3))) error stop
    if (p /= 5) error stop
    if (j /= maxloc(x, 1)) error stop
    if (j /= 3) error stop
    a = 0.0
    ! diag_a (maxval, this file) and diag_b (minval, the other file) need
    ! different helpers for their result shape, which may get the same name
    ! in both object files.
    d = multi_file_intrinsic_01_diag_a(a)
    e = multi_file_intrinsic_01_diag_b(a)
    print *, d, e
    if (size(multi_file_intrinsic_01_diag_a(a)) /= 3) error stop
    if (size(multi_file_intrinsic_01_diag_b(a)) /= 2) error stop
    if (any(abs(d - 2.0) > 1e-5)) error stop
    if (any(abs(e - 1.0) > 1e-5)) error stop
end program multi_file_intrinsic_01

function multi_file_intrinsic_01_diag_a(a) result(res)
    implicit none
    real, intent(in) :: a(:,:)
    real :: res(maxval(shape(a)))
    res = 2.0
end function multi_file_intrinsic_01_diag_a

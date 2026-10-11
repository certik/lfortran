subroutine multi_file_intrinsic_01_ext(x, n, r, s, k, m, p, j)
    implicit none
    integer, intent(in) :: n
    real, intent(in) :: x(n)
    real, intent(out) :: r, s(n)
    integer, intent(out) :: k, m, p, j
    integer :: ia(3)
    ia = [7, 5, 6]
    r = sum(x) + sin(x(1)) + maxval(x) + product(x)
    s = sin(x)
    k = iall(ia)
    m = merge(1, 2, any(x > 2.0)) + count(x > 1.5)
    p = modulo(ia(1), 4) + exponent(x(3))
    j = maxloc(x, 1)
end subroutine multi_file_intrinsic_01_ext

function multi_file_intrinsic_01_diag_b(a) result(res)
    implicit none
    real, intent(in) :: a(:,:)
    real :: res(minval(shape(a)))
    res = 1.0
end function multi_file_intrinsic_01_diag_b

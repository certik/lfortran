! Solve the 1D Poisson equation
!
!     -u''(x) = f(x),   0 < x < 1,   u(0) = u(1) = 0
!
! on the uniform grid x_i = i*h, h = 1/(n+1), i = 0, ..., n+1, using the
! second order central difference
!
!     (-u_{i-1} + 2 u_i - u_{i+1}) / h^2 = f(x_i),   i = 1, ..., n.
!
! The resulting tridiagonal system is solved with the Thomas algorithm.
! The Lean model of this file is in FortranLean/Poisson.lean.
module poisson_mod
implicit none
integer, parameter :: dp = kind(0.d0)

contains

! Tridiagonal solver: a(i) x(i-1) + b(i) x(i) + c(i) x(i+1) = d(i),
! i = 1, ..., n, where a(1) and c(n) are not used.
subroutine thomas(n, a, b, c, d, x)
integer, intent(in) :: n
real(dp), intent(in) :: a(n), b(n), c(n), d(n)
real(dp), intent(out) :: x(n)
real(dp) :: cp(n), dq(n), m
integer :: i
cp(1) = c(1) / b(1)
dq(1) = d(1) / b(1)
do i = 2, n
    m = b(i) - a(i) * cp(i-1)
    cp(i) = c(i) / m
    dq(i) = (d(i) - a(i) * dq(i-1)) / m
end do
x(n) = dq(n)
do i = n-1, 1, -1
    x(i) = dq(i) - cp(i) * x(i+1)
end do
end subroutine

! Assemble the finite difference system for -u'' = f and solve it.
! f(i) is the right hand side at the interior grid point x_i = i*h.
subroutine solve_poisson(n, f, u)
integer, intent(in) :: n
real(dp), intent(in) :: f(n)
real(dp), intent(out) :: u(n)
real(dp) :: a(n), b(n), c(n), d(n), h
integer :: i
h = 1.0_dp / (n + 1)
do i = 1, n
    a(i) = -1
    b(i) = 2
    c(i) = -1
    d(i) = h**2 * f(i)
end do
call thomas(n, a, b, c, d, u)
end subroutine

end module

program poisson
use poisson_mod, only: dp, solve_poisson
implicit none
integer, parameter :: n = 9
real(dp) :: f(n), u(n), x, h, err
integer :: i
h = 1.0_dp / (n + 1)
! Exact solution u(x) = x (1 - x) (1 + x) = x - x^3, so -u''(x) = 6 x.
! The central difference is exact for cubics, so the discrete solution
! agrees with u at the grid points up to rounding.
do i = 1, n
    x = i * h
    f(i) = 6 * x
end do
call solve_poisson(n, f, u)
err = 0
do i = 1, n
    x = i * h
    print "(i3, 2f22.16)", i, u(i), x - x**3
    err = max(err, abs(u(i) - (x - x**3)))
end do
print *, "max error:", err
if (err > 1e-14_dp) error stop
end program

! Test: bind(c) functions suitable for shared library compilation
module bindc_14_mod
use iso_c_binding, only: c_float, c_int
implicit none
contains

function square(x) result(xsq) bind(c)
  real(c_float), value :: x
  real(c_float) :: xsq
  xsq = x * x
end function

function add_ints(a, b) result(c) bind(c)
  integer(c_int), value :: a, b
  integer(c_int) :: c
  c = a + b
end function

end module

program bindc_14
use bindc_14_mod
use iso_c_binding, only: c_float, c_int
implicit none

real(c_float) :: r
integer(c_int) :: i

r = square(3.0_c_float)
if (abs(r - 9.0_c_float) > 1.0e-6_c_float) error stop

i = add_ints(10_c_int, 20_c_int)
if (i /= 30) error stop

print *, "ok"
end program

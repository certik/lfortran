program gpu_metal_199
! Test: parameter constants used in contained functions inside do concurrent
! Ensures the Metal code generator emits parent-scope parameter constants
! within inline functions for contained procedures.
implicit none
real, parameter :: t = 1.0, f = 0.0
integer, parameter :: n = 4
real :: h(n), r(n)
integer :: i
h = [0.2, 0.8, 0.3, 0.9]
do concurrent(i=1:n)
    r(i) = merge(t, f, h(i) > 0.5) + classify(h(i))
end do
print *, r
if (abs(r(1) - 0.0) > 1e-6) error stop
if (abs(r(2) - 2.0) > 1e-6) error stop
if (abs(r(3) - 0.0) > 1e-6) error stop
if (abs(r(4) - 2.0) > 1e-6) error stop
contains
    pure real function classify(x)
        real, intent(in) :: x
        classify = merge(t, f, x > 0.5)
    end function
end program

program gpu_metal_234
! Test: do concurrent with structure constructor of nested derived types
! with allocatable components, exercising --gpu=metal code path.
! Regression test: the second member was previously dropped when
! decomposing the StructConstructor in the GPU offload pass because
! an ExternalSymbol was not created for unreferenced struct members.
implicit none
type :: inner_t
  real, allocatable :: v(:)
end type
type :: outer_t
  type(inner_t) :: a, b
end type
type(inner_t) :: x(2), y(2)
type(outer_t) :: p(2)
integer :: i

x(1) = inner_t([1.0, 2.0])
x(2) = inner_t([3.0, 4.0])
y(1) = inner_t([10.0, 20.0])
y(2) = inner_t([30.0, 40.0])

do concurrent(i = 1:2)
  p(i) = outer_t(x(i), y(i))
end do

! Verify first element
if (abs(p(1)%a%v(1) - 1.0) > 1e-6) error stop
if (abs(p(1)%a%v(2) - 2.0) > 1e-6) error stop
if (abs(p(1)%b%v(1) - 10.0) > 1e-6) error stop
if (abs(p(1)%b%v(2) - 20.0) > 1e-6) error stop

! Verify second element
if (abs(p(2)%a%v(1) - 3.0) > 1e-6) error stop
if (abs(p(2)%a%v(2) - 4.0) > 1e-6) error stop
if (abs(p(2)%b%v(1) - 30.0) > 1e-6) error stop
if (abs(p(2)%b%v(2) - 40.0) > 1e-6) error stop

print *, "PASS"
end program

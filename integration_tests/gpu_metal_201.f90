program gpu_metal_201
  ! Test: Metal address space mismatch for derived type construction
  ! via function call chain inside do concurrent.
  ! A device-context function calling another function that takes a
  ! thread-local array constant and returns a derived type result
  ! requires a mixed address-space overload (thread arrays + device
  ! struct out).
  implicit none

  type :: dt
    real :: v
  end type

  type(dt) :: arr(4)
  integer :: i

  do concurrent(i=1:4)
    arr(i) = local_fn(real(i))
  end do

  if (abs(arr(1)%v - 2.0) > 1e-6) error stop
  if (abs(arr(2)%v - 3.0) > 1e-6) error stop
  if (abs(arr(3)%v - 4.0) > 1e-6) error stop
  if (abs(arr(4)%v - 5.0) > 1e-6) error stop
  print *, "ok"

contains

  pure function make_dt(values) result(r)
    real, intent(in) :: values(:)
    type(dt) :: r
    r%v = values(1)
  end function

  pure function local_fn(x) result(r)
    real, intent(in) :: x
    type(dt) :: r
    r = make_dt([x + 1.0])
  end function

end program

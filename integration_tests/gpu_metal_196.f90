program gpu_metal_196
  implicit none
  type :: vec_t
    real, allocatable :: v(:)
  end type
  type(vec_t) :: arr(2)
  integer :: i
  allocate(arr(1)%v(1))
  allocate(arr(2)%v(1))
  arr(1)%v(1) = 1.0
  arr(2)%v(1) = 2.0
  do concurrent(i = 1:2)
    arr(i) = copy_it(arr(i))
  end do
  if (abs(arr(1)%v(1) - 1.0) > 1.0e-6) error stop
  if (abs(arr(2)%v(1) - 2.0) > 1.0e-6) error stop
  print *, "ok"
contains
  pure function copy_it(inp) result(res)
    type(vec_t), intent(in) :: inp
    type(vec_t) :: res
    res%v = inp%v
  end function
end program

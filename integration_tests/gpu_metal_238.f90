program gpu_metal_238
  implicit none

  type :: inner_t
    real, allocatable :: x(:)
  end type

  type :: outer_t
    type(inner_t), allocatable :: items(:)
  end type

  type(outer_t) :: arr(1)
  integer :: i

  do concurrent (i = 1:1)
    arr(i) = outer_t([inner_t([1.0])])
  end do

  if (size(arr(1)%items) /= 1) error stop
  if (abs(arr(1)%items(1)%x(1) - 1.0) > 1e-6) error stop
  print *, "ok"
end program

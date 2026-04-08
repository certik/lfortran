program gpu_metal_221
  ! Test do concurrent with nested derived type assignment:
  ! outer_t has allocatable items(:) of inner_t, inner_t has allocatable v(:)
  implicit none
  type :: inner_t
    real, allocatable :: v(:)
  end type
  type :: outer_t
    type(inner_t), allocatable :: items(:)
  end type
  integer, parameter :: n = 4
  type(inner_t) :: inputs(n)
  type(outer_t) :: batches(n)
  integer :: i

  do i = 1, n
    allocate(inputs(i)%v(2))
    inputs(i)%v = [real :: i, i+1]
    allocate(batches(i)%items(1))
  end do

  do concurrent(i = 1:n)
    batches(i)%items(1) = inputs(i)
  end do

  if (batches(1)%items(1)%v(1) /= 1.0) error stop
  if (batches(1)%items(1)%v(2) /= 2.0) error stop
  if (batches(2)%items(1)%v(1) /= 2.0) error stop
  if (batches(2)%items(1)%v(2) /= 3.0) error stop
  if (batches(3)%items(1)%v(1) /= 3.0) error stop
  if (batches(3)%items(1)%v(2) /= 4.0) error stop
  if (batches(4)%items(1)%v(1) /= 4.0) error stop
  if (batches(4)%items(1)%v(2) /= 5.0) error stop
  print *, "PASS"
end program

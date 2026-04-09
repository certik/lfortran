program gpu_metal_240
  ! Test: elemental function returning derived type with nested
  ! allocatable component inside do concurrent (GPU offloading).
  implicit none

  type :: tensor_t
    real, allocatable :: v(:)
  end type

  type :: pair_t
    type(tensor_t) :: x
  end type

  type :: batch_t
    type(pair_t), allocatable :: p(:)
  end type

  type(tensor_t) :: inp(1)
  type(batch_t) :: bat(1)
  integer :: i

  inp(1) = tensor_t([1.0, 2.0])

  do concurrent (i = 1:1)
    bat(i) = batch_t([make_pair(inp(i))])
  end do

  if (size(bat(1)%p(1)%x%v) /= 2) error stop
  if (bat(1)%p(1)%x%v(1) /= 1.0) error stop
  if (bat(1)%p(1)%x%v(2) /= 2.0) error stop
  print *, "PASSED"

contains

  elemental function make_pair(t) result(r)
    type(tensor_t), intent(in) :: t
    type(pair_t) :: r
    r%x = t
  end function

end program

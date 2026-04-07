! Test: derived type with allocatable sub-component inside
! do concurrent, passed to a function returning a simple struct.
! Verifies Metal codegen handles Pointer(Array(StructType)) correctly
! for temporary variables and generates proper companion variables.
program gpu_metal_202
  implicit none

  type :: tensor_t
    real, allocatable :: values_(:)
  end type

  type :: info_t
    integer :: len_
  end type

  type(tensor_t) :: arr(4)
  type(info_t) :: res(4)
  integer :: j

  arr(1) = make_tensor([1.0])
  arr(2) = make_tensor([2.0, 3.0])
  arr(3) = make_tensor([4.0, 5.0, 6.0])
  arr(4) = make_tensor([7.0])

  do concurrent(j=1:4)
    res(j) = get_info(arr(j))
  end do

  if (res(1)%len_ /= 1) error stop
  if (res(2)%len_ /= 2) error stop
  if (res(3)%len_ /= 3) error stop
  if (res(4)%len_ /= 1) error stop
  print *, "PASS"

contains

  pure function make_tensor(vals) result(t)
    real, intent(in) :: vals(:)
    type(tensor_t) :: t
    t%values_ = vals
  end function

  elemental function get_info(d) result(r)
    type(tensor_t), intent(in) :: d
    type(info_t) :: r
    r%len_ = size(d%values_)
  end function

end program

! Test: function returning derived type with allocatable component
! called inside do concurrent with multi-dimensional array of structs.
! Verifies Metal codegen correctly linearizes multi-dim array indices
! for struct-from-array-elem tracking and handles unallocated output
! allocatable members during host-side buffer setup.
program gpu_metal_197
  implicit none
  type :: vec_t
    real, allocatable :: v(:)
  end type
  integer :: i
  type(vec_t) :: inp(1, 2), out(1, 2)

  inp(1,1) = vec_t([1.0])
  inp(1,2) = vec_t([2.0])

  do concurrent(i=1:2)
    out(1, i) = copy_fn(inp(1, i))
  end do

  print *, out(1,1)%v(1)
  print *, out(1,2)%v(1)
  if (abs(out(1,1)%v(1) - 1.0) > 1e-6) error stop
  if (abs(out(1,2)%v(1) - 2.0) > 1e-6) error stop
  print *, "PASS"

contains
  pure function copy_fn(x) result(y)
    type(vec_t), intent(in) :: x
    type(vec_t) :: y
    y = vec_t(x%v)
  end function
end program

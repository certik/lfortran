program gpu_metal_258
  ! Test: intent(in) parameter arrays passed to do concurrent GPU kernels.
  ! Verifies that read-only (parameter/intent(in)) arrays are not written
  ! back to host memory after GPU kernel execution, which previously caused
  ! a Bus error when the host pointer was in read-only memory.
  implicit none
  integer, parameter :: n(3) = [10, 20, 30]
  integer :: r(3)
  r = 0
  call copy_param(n, r)
  if (r(1) /= 10) error stop
  if (r(2) /= 20) error stop
  if (r(3) /= 30) error stop
  print *, "ok"
contains
  subroutine copy_param(src, dst)
    integer, intent(in) :: src(:)
    integer, intent(out) :: dst(:)
    integer :: i
    do concurrent(i = 1:size(src))
      dst(i) = src(i)
    end do
  end subroutine
end program

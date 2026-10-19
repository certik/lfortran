! An element of an array of derived type reached through a component --
! `self%points_(1,1,1,1)%values_` -- is handed to the kernel through a
! pointer bound to the element on the host, not through a copy of it. The
! kernel reads and writes the element's own storage, so a written element
! needs nothing copied back, and the loop bounds that name the element do
! not make the whole object a kernel argument.
!
! Every operand shape is checked against the values the host computes:
! a read-only element, a written element (in full and in part), several
! read-only elements of one object, an element reached through two levels
! of components, and an element whose scalar component is read too. A
! final subroutine of the element's type must never run for the binding.
module gpu_metal_486_m
   implicit none

   integer :: finalized = 0

   type :: points_t
      real :: w_ = 1.0
      real, allocatable :: values_(:,:)
   contains
      final :: count_final
   end type points_t

   type :: tensor_t
      type(points_t), allocatable :: points_(:,:,:,:)
   end type tensor_t

   type :: inner_t
      real, allocatable :: values_(:)
   end type inner_t

   type :: outer_t
      type(inner_t), allocatable :: inner_(:)
   end type outer_t

   type :: nest_t
      type(outer_t), allocatable :: outer_(:)
   end type nest_t

contains

   subroutine count_final(self)
      type(points_t), intent(inout) :: self
      finalized = finalized + 1
   end subroutine count_final

   ! A read-only element, also named by the loop bounds.
   subroutine twice(self, out)
      type(tensor_t), intent(in) :: self
      real, intent(out) :: out(:,:)
      integer :: j
      do concurrent (j = 1:size(self%points_(1,1,1,1)%values_, 2))
         out(:,j) = 2*self%points_(1,1,1,1)%values_(:,j)
      end do
   end subroutine twice

   ! A written element, read from another object's element.
   subroutine scale(self, out, w)
      type(tensor_t), intent(in) :: self
      type(tensor_t), intent(inout) :: out
      real, intent(in) :: w
      integer :: j
      do concurrent (j = 1:size(self%points_(1,1,1,1)%values_, 2))
         out%points_(1,1,1,1)%values_(:,j) = &
            w*self%points_(1,1,1,1)%values_(:,j)
      end do
   end subroutine scale

   ! Only the first two columns are written; the rest must stay.
   subroutine scale_first_two(self, out, w)
      type(tensor_t), intent(in) :: self
      type(tensor_t), intent(inout) :: out
      real, intent(in) :: w
      integer :: j
      do concurrent (j = 1:2)
         out%points_(1,1,1,1)%values_(:,j) = &
            w*self%points_(1,1,1,1)%values_(:,j)
      end do
   end subroutine scale_first_two

   ! An element read and written in place.
   subroutine accumulate(out, w)
      type(tensor_t), intent(inout) :: out
      real, intent(in) :: w
      integer :: j
      do concurrent (j = 1:size(out%points_(1,1,1,1)%values_, 2))
         out%points_(1,1,1,1)%values_(:,j) = &
            out%points_(1,1,1,1)%values_(:,j) + w
      end do
   end subroutine accumulate

   ! Two read-only elements of the same object.
   subroutine difference(self, out)
      type(tensor_t), intent(in) :: self
      real, intent(out) :: out(:,:)
      integer :: j
      do concurrent (j = 1:size(out, 2))
         out(:,j) = self%points_(2,1,1,1)%values_(:,j) &
            - self%points_(1,1,1,1)%values_(:,j)
      end do
   end subroutine difference

   ! The scalar component of the element is read as well.
   subroutine weighted(self, out)
      type(tensor_t), intent(in) :: self
      real, intent(out) :: out(:,:)
      integer :: j
      do concurrent (j = 1:size(out, 2))
         out(:,j) = self%points_(1,1,1,1)%w_ &
            * self%points_(1,1,1,1)%values_(:,j)
      end do
   end subroutine weighted

   ! An element two levels of components down.
   subroutine nested(self, out)
      type(nest_t), intent(in) :: self
      real, intent(out) :: out(:)
      integer :: i
      do concurrent (i = 1:size(self%outer_(2)%inner_(3)%values_))
         out(i) = self%outer_(2)%inner_(3)%values_(i) + 1
      end do
   end subroutine nested

end module gpu_metal_486_m

program gpu_metal_486
   use gpu_metal_486_m
   implicit none
   integer, parameter :: nx = 5, ny = 7
   type(tensor_t) :: a, b
   type(nest_t) :: c
   real :: r(nx, ny), s(nx)
   real :: w
   integer :: i, j, k, pass

   allocate(a%points_(2,1,1,1), b%points_(1,1,1,1))
   allocate(a%points_(1,1,1,1)%values_(nx, ny))
   allocate(a%points_(2,1,1,1)%values_(nx, ny))
   allocate(b%points_(1,1,1,1)%values_(nx, ny))
   do j = 1, ny
      do i = 1, nx
         a%points_(1,1,1,1)%values_(i,j) = real(i + 10*j)
         a%points_(2,1,1,1)%values_(i,j) = real(3*i - j)
      end do
   end do
   a%points_(1,1,1,1)%w_ = 0.5

   allocate(c%outer_(2))
   allocate(c%outer_(2)%inner_(3))
   allocate(c%outer_(2)%inner_(3)%values_(nx))
   do i = 1, nx
      c%outer_(2)%inner_(3)%values_(i) = real(7*i)
   end do

   finalized = 0
   ! Several passes with distinct weights: a stale copy or a lost write
   ! shows up as the value of an earlier pass.
   do pass = 1, 3
      w = real(pass) + 0.25

      r = 0
      call twice(a, r)
      do j = 1, ny
         do i = 1, nx
            if (abs(r(i,j) - 2*real(i + 10*j)) > 1e-4) error stop "twice"
         end do
      end do

      b%points_(1,1,1,1)%values_ = -1
      call scale(a, b, w)
      do j = 1, ny
         do i = 1, nx
            if (abs(b%points_(1,1,1,1)%values_(i,j) &
                  - w*real(i + 10*j)) > 1e-4) error stop "scale"
         end do
      end do

      b%points_(1,1,1,1)%values_ = -1
      call scale_first_two(a, b, w)
      do j = 1, ny
         do i = 1, nx
            if (j <= 2) then
               if (abs(b%points_(1,1,1,1)%values_(i,j) &
                     - w*real(i + 10*j)) > 1e-4) error stop "first two"
            else
               if (abs(b%points_(1,1,1,1)%values_(i,j) + 1) > 1e-4) then
                  error stop "untouched"
               end if
            end if
         end do
      end do

      call accumulate(b, w)
      call accumulate(b, 1.0)
      do j = 1, ny
         do i = 1, nx
            if (j <= 2) then
               if (abs(b%points_(1,1,1,1)%values_(i,j) &
                     - (w*real(i + 10*j) + w + 1)) > 1e-3) then
                  error stop "accumulate"
               end if
            else
               if (abs(b%points_(1,1,1,1)%values_(i,j) - w) > 1e-4) then
                  error stop "accumulate untouched"
               end if
            end if
         end do
      end do

      r = 0
      call difference(a, r)
      do j = 1, ny
         do i = 1, nx
            if (abs(r(i,j) - real(3*i - j - i - 10*j)) > 1e-4) then
               error stop "difference"
            end if
         end do
      end do

      r = 0
      call weighted(a, r)
      do j = 1, ny
         do i = 1, nx
            if (abs(r(i,j) - 0.5*real(i + 10*j)) > 1e-4) then
               error stop "weighted"
            end if
         end do
      end do

      s = 0
      call nested(c, s)
      do i = 1, nx
         if (abs(s(i) - real(7*i + 1)) > 1e-4) error stop "nested"
      end do
      c%outer_(2)%inner_(3)%values_ = c%outer_(2)%inner_(3)%values_ + 0
   end do

   ! The source objects are unchanged.
   do j = 1, ny
      do i = 1, nx
         if (abs(a%points_(1,1,1,1)%values_(i,j) - real(i + 10*j)) > 0) then
            error stop "source changed"
         end if
      end do
   end do
   k = finalized
   print *, "finalized", k
   if (k /= 0) error stop "an element was finalized"
   print *, "ok"
end program gpu_metal_486
